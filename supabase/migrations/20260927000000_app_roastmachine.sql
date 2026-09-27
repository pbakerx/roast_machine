-- Roast Machine lives in its own schema inside the shared Second-Brain project
-- (one schema per app; see CLAUDE.md → Backend). Nothing here is exposed to the
-- public API: RLS on with no policies, no grants to anon/authenticated, and the
-- schema is not in PostgREST's exposed list. The only door is the
-- `roastmachine` Edge Function, which connects as the database owner.
--
-- Additive and safe to re-run.

create schema if not exists app_roastmachine;
revoke all on schema app_roastmachine from public, anon, authenticated;

-- A wallet is one player's ticket balance. Its id is a random UUID the app
-- keeps in the (iCloud-synced) keychain, so tickets survive reinstalls and
-- follow the user's devices. It is also the StoreKit appAccountToken.
create table if not exists app_roastmachine.wallets (
  id               uuid primary key,
  tickets          integer     not null default 0 check (tickets >= 0),
  free_roast_used  boolean     not null default false,
  free_hype_used   boolean     not null default false,
  created_at       timestamptz not null default now()
);

-- App Attest keys: one per install, each proven to be the genuine app on a
-- genuine iPhone. Every request is signed by one of these.
create table if not exists app_roastmachine.attest_keys (
  key_id        text        primary key,          -- base64 key identifier
  wallet_id     uuid        not null references app_roastmachine.wallets(id) on delete cascade,
  public_key    bytea       not null,             -- SPKI DER
  counter       bigint      not null default 0,   -- assertions must strictly increase it
  environment   text        not null check (environment in ('development', 'production')),
  created_at    timestamptz not null default now(),
  last_seen_at  timestamptz
);
create index if not exists attest_keys_wallet_idx on app_roastmachine.attest_keys (wallet_id);

-- One-time attestation challenges (expire after 5 minutes).
create table if not exists app_roastmachine.challenges (
  id          uuid        primary key default gen_random_uuid(),
  challenge   bytea       not null,
  created_at  timestamptz not null default now(),
  used_at     timestamptz
);

-- Verified App Store transactions. transaction_id makes crediting idempotent.
create table if not exists app_roastmachine.purchases (
  transaction_id  text        primary key,
  wallet_id       uuid        not null references app_roastmachine.wallets(id) on delete cascade,
  product_id      text        not null,
  tickets         integer     not null check (tickets > 0),
  environment     text        not null,
  created_at      timestamptz not null default now()
);

-- One row per show. `script` is held only until the voice call and then
-- cleared; no photo is ever stored. ip_hash is salted, for rate limiting only.
create table if not exists app_roastmachine.shows (
  id            uuid        primary key default gen_random_uuid(),
  wallet_id     uuid        not null references app_roastmachine.wallets(id) on delete cascade,
  mode_id       text        not null,
  flavor        text        not null check (flavor in ('roast', 'compliment')),
  paid_with     text        not null check (paid_with in ('free', 'ticket', 'dev')),
  script        text,
  script_chars  integer,
  voiced_at     timestamptz,
  refunded_at   timestamptz,
  ip_hash       text        not null default '',
  created_at    timestamptz not null default now()
);
create index if not exists shows_wallet_created_idx on app_roastmachine.shows (wallet_id, created_at desc);
create index if not exists shows_ip_created_idx     on app_roastmachine.shows (ip_hash, created_at desc);
create index if not exists shows_created_idx        on app_roastmachine.shows (created_at desc);

alter table app_roastmachine.wallets     enable row level security;
alter table app_roastmachine.attest_keys enable row level security;
alter table app_roastmachine.challenges  enable row level security;
alter table app_roastmachine.purchases   enable row level security;
alter table app_roastmachine.shows       enable row level security;
-- Deliberately no policies. Do not add one to "make it work".

-- ---------------------------------------------------------------------------
-- Wallet as the app sees it.
create or replace function app_roastmachine.wallet_json(p_wallet uuid)
returns jsonb language sql stable as $$
  select jsonb_build_object(
    'tickets',    w.tickets,
    'free_roast', not w.free_roast_used,
    'free_hype',  not w.free_hype_used)
  from app_roastmachine.wallets w where w.id = p_wallet
$$;

-- Spend one show atomically: rate limits first, then a free run for that
-- flavor if unused, else a ticket. Returns {ok, reason?, show_id, wallet}.
create or replace function app_roastmachine.spend_show(
  p_wallet uuid, p_mode text, p_flavor text, p_ip_hash text, p_dev boolean,
  p_daily_cap int, p_ip_hourly_cap int, p_global_daily_cap int)
returns jsonb language plpgsql as $$
declare
  w       app_roastmachine.wallets%rowtype;
  v_paid  text;
  v_show  uuid;
begin
  select * into w from app_roastmachine.wallets where id = p_wallet for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'unknown_wallet');
  end if;

  if (select count(*) from app_roastmachine.shows
      where created_at > now() - interval '1 day' and refunded_at is null) >= p_global_daily_cap then
    return jsonb_build_object('ok', false, 'reason', 'busy');
  end if;
  if (select count(*) from app_roastmachine.shows
      where wallet_id = p_wallet and created_at > now() - interval '1 day' and refunded_at is null) >= p_daily_cap then
    return jsonb_build_object('ok', false, 'reason', 'daily_cap');
  end if;
  if p_ip_hash <> '' and (select count(*) from app_roastmachine.shows
      where ip_hash = p_ip_hash and created_at > now() - interval '1 hour' and refunded_at is null) >= p_ip_hourly_cap then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;

  if p_dev then
    v_paid := 'dev';
  elsif p_flavor = 'roast' and not w.free_roast_used then
    update app_roastmachine.wallets set free_roast_used = true where id = p_wallet;
    v_paid := 'free';
  elsif p_flavor = 'compliment' and not w.free_hype_used then
    update app_roastmachine.wallets set free_hype_used = true where id = p_wallet;
    v_paid := 'free';
  elsif w.tickets > 0 then
    update app_roastmachine.wallets set tickets = tickets - 1 where id = p_wallet;
    v_paid := 'ticket';
  else
    return jsonb_build_object('ok', false, 'reason', 'no_tickets',
                              'wallet', app_roastmachine.wallet_json(p_wallet));
  end if;

  insert into app_roastmachine.shows (wallet_id, mode_id, flavor, paid_with, ip_hash)
  values (p_wallet, p_mode, p_flavor, v_paid, p_ip_hash)
  returning id into v_show;

  return jsonb_build_object('ok', true, 'show_id', v_show,
                            'wallet', app_roastmachine.wallet_json(p_wallet));
end $$;

-- Give back whatever a failed show spent. Idempotent.
create or replace function app_roastmachine.refund_show(p_show uuid)
returns jsonb language plpgsql as $$
declare s app_roastmachine.shows%rowtype;
begin
  update app_roastmachine.shows set refunded_at = now(), script = null
  where id = p_show and refunded_at is null
  returning * into s;
  if not found then return null; end if;

  if s.paid_with = 'ticket' then
    update app_roastmachine.wallets set tickets = tickets + 1 where id = s.wallet_id;
  elsif s.paid_with = 'free' and s.flavor = 'roast' then
    update app_roastmachine.wallets set free_roast_used = false where id = s.wallet_id;
  elsif s.paid_with = 'free' and s.flavor = 'compliment' then
    update app_roastmachine.wallets set free_hype_used = false where id = s.wallet_id;
  end if;
  return app_roastmachine.wallet_json(s.wallet_id);
end $$;

-- Credit a verified purchase once. Returns {credited, wallet}.
create or replace function app_roastmachine.credit_purchase(
  p_tx text, p_wallet uuid, p_product text, p_tickets int, p_env text)
returns jsonb language plpgsql as $$
declare v_rows int;
begin
  insert into app_roastmachine.wallets (id) values (p_wallet) on conflict (id) do nothing;
  insert into app_roastmachine.purchases (transaction_id, wallet_id, product_id, tickets, environment)
  values (p_tx, p_wallet, p_product, p_tickets, p_env)
  on conflict (transaction_id) do nothing;
  get diagnostics v_rows = row_count;
  if v_rows > 0 then
    update app_roastmachine.wallets set tickets = tickets + p_tickets where id = p_wallet;
  end if;
  return jsonb_build_object('credited', v_rows > 0, 'wallet', app_roastmachine.wallet_json(p_wallet));
end $$;

revoke all on all functions in schema app_roastmachine from public, anon, authenticated;
