//
//  RoastStickers.swift
//  RoastMachine
//
//  Turns the roast transcript into a timed stream of big comedy graphics.
//  If the chef screams about an undercooked tomato, a tomato slams onto the
//  screen right as the word lands. Timing is estimated from where the word
//  sits in the script relative to the audio duration.
//

import Foundation
import CoreGraphics

enum RoastStickers {

    /// One sticker scheduled to pop in during playback.
    struct Event: Identifiable, Equatable {
        let id: Int
        let emoji: String
        /// 0...1 fraction of the audio at which the word lands.
        let fraction: Double
        /// Position in unit coordinates (kept off the face).
        let x: CGFloat
        let y: CGFloat
        let rotation: Double
        let size: CGFloat
    }

    /// Concrete, drawable nouns (and a few verbs) worth celebrating on screen.
    static let lexicon: [String: String] = [
        // kitchen & food
        "tomato": "🍅", "carrot": "🥕", "onion": "🧅", "potato": "🥔", "broccoli": "🥦",
        "corn": "🌽", "pepper": "🌶️", "mushroom": "🍄", "garlic": "🧄", "lettuce": "🥬",
        "cucumber": "🥒", "eggplant": "🍆", "avocado": "🥑", "pizza": "🍕", "burger": "🍔",
        "sandwich": "🥪", "hotdog": "🌭", "taco": "🌮", "spaghetti": "🍝", "pasta": "🍝",
        "noodle": "🍜", "soup": "🍲", "salad": "🥗", "egg": "🍳", "bacon": "🥓",
        "toast": "🍞", "bread": "🍞", "cheese": "🧀", "steak": "🥩", "chicken": "🍗",
        "turkey": "🦃", "fish": "🐟", "shrimp": "🍤", "sushi": "🍣", "cake": "🎂",
        "cookie": "🍪", "donut": "🍩", "pancake": "🥞", "waffle": "🧇", "pie": "🥧",
        "icecream": "🍦", "candy": "🍬", "chocolate": "🍫", "popcorn": "🍿", "banana": "🍌",
        "apple": "🍎", "lemon": "🍋", "grape": "🍇", "watermelon": "🍉", "peach": "🍑",
        "pineapple": "🍍", "coconut": "🥥", "milk": "🥛", "coffee": "☕", "tea": "🍵",
        "wine": "🍷", "beer": "🍺", "cocktail": "🍸", "salt": "🧂", "butter": "🧈",
        "microwave": "📺", "oven": "🔥", "pan": "🍳", "knife": "🔪", "raw": "🥩",
        // fashion & look
        "hair": "💇", "haircut": "💈", "mustache": "👨", "beard": "🧔", "wig": "👱",
        "hat": "🎩", "cap": "🧢", "crown": "👑", "glasses": "👓", "sunglasses": "🕶️",
        "shirt": "👕", "jacket": "🧥", "coat": "🧥", "dress": "👗", "jeans": "👖",
        "pants": "👖", "sock": "🧦", "shoe": "👟", "sneaker": "👟", "boot": "👢",
        "tie": "👔", "scarf": "🧣", "glove": "🧤", "purse": "👜", "watch": "⌚",
        "ring": "💍", "lipstick": "💄", "mirror": "🪞", "perfume": "🧴",
        // stage & music
        "microphone": "🎤", "mic": "🎤", "guitar": "🎸", "drum": "🥁", "piano": "🎹",
        "trumpet": "🎺", "violin": "🎻", "spotlight": "🔦", "stage": "🎭", "ticket": "🎟️",
        "trophy": "🏆", "medal": "🏅", "star": "⭐", "fire": "🔥", "flame": "🔥",
        "bomb": "💣", "explosion": "💥", "confetti": "🎊", "balloon": "🎈", "party": "🎉",
        // animals
        "dog": "🐶", "puppy": "🐶", "cat": "🐱", "kitten": "🐱", "goat": "🐐",
        "lion": "🦁", "tiger": "🐯", "bear": "🐻", "monkey": "🐵", "gorilla": "🦍",
        "horse": "🐴", "cow": "🐮", "pig": "🐷", "sheep": "🐑", "duck": "🦆",
        "owl": "🦉", "eagle": "🦅", "penguin": "🐧", "frog": "🐸", "snake": "🐍",
        "dinosaur": "🦖", "dragon": "🐉", "unicorn": "🦄", "sloth": "🦥", "peacock": "🦚",
        "flamingo": "🦩", "squirrel": "🐿️", "raccoon": "🦝", "skunk": "🦨", "hamster": "🐹",
        // work & tech
        "laptop": "💻", "computer": "💻", "phone": "📱", "email": "📧", "briefcase": "💼",
        "meeting": "📊", "chart": "📈", "graph": "📈", "spreadsheet": "📊", "printer": "🖨️",
        "robot": "🤖", "battery": "🔋", "wifi": "📶", "camera": "📷", "selfie": "🤳",
        // mystic & misc
        "moon": "🌙", "sun": "☀️", "rainbow": "🌈", "cloud": "☁️", "storm": "⛈️",
        "crystal": "🔮", "magic": "✨", "ghost": "👻", "alien": "👽", "skull": "💀",
        "clown": "🤡", "wizard": "🧙", "genie": "🧞", "mermaid": "🧜", "fairy": "🧚",
        "heart": "❤️", "kiss": "💋", "rose": "🌹", "flower": "🌸", "cactus": "🌵",
        "tree": "🌳", "leaf": "🍃", "jungle": "🌴", "mountain": "⛰️", "beach": "🏖️",
        "money": "💰", "dollar": "💵", "gold": "🥇", "diamond": "💎", "gem": "💎",
        "muscle": "💪", "gym": "🏋️", "pushup": "💪", "boot_camp": "🎖️", "flag": "🚩",
        "car": "🚗", "truck": "🚚", "rocket": "🚀", "boat": "⛵", "bike": "🚲",
        "couch": "🛋️", "sofa": "🛋️", "bed": "🛏️", "lamp": "💡", "clock": "⏰",
        "book": "📚", "quill": "🪶", "scroll": "📜", "letter": "💌", "map": "🗺️",
        "key": "🔑", "lock": "🔒", "umbrella": "☂️", "sword": "⚔️", "shield": "🛡️",
        "eye": "👁️", "eyebrow": "🤨", "tooth": "🦷", "teeth": "😬", "smile": "😁",
        "wink": "😉", "tear": "😢", "sweat": "💦", "yawn": "🥱", "snore": "😴"
    ]

    /// Extract timed sticker events from a script. Caps the count and spaces
    /// events out so the screen never turns into soup.
    static func events(for script: String) -> [Event] {
        guard !script.isEmpty else { return [] }
        let total = Double(script.count)
        var events: [Event] = []
        var lastFraction = -1.0
        var index = 0

        var offset = 0
        for rawWord in script.split(separator: " ", omittingEmptySubsequences: false) {
            defer { offset += rawWord.count + 1 }
            let word = rawWord.lowercased()
                .trimmingCharacters(in: .alphanumerics.inverted)
            guard !word.isEmpty else { continue }

            var emoji = lexicon[word]
            if emoji == nil, word.hasSuffix("s") {          // plain plural
                emoji = lexicon[String(word.dropLast())]
            }
            if emoji == nil, word.hasSuffix("es") {
                emoji = lexicon[String(word.dropLast(2))]
            }
            guard let emoji else { continue }

            let fraction = min(0.97, Double(offset) / total)
            guard fraction - lastFraction >= 0.05 else { continue }   // breathing room
            lastFraction = fraction

            events.append(placed(emoji: emoji, fraction: fraction, index: index, seed: word))
            index += 1
            if events.count >= 12 { break }
        }
        return events
    }

    /// Deterministic zany placement: alternating edge columns, cycling rows,
    /// jitter hashed from the word so reruns look identical.
    private static func placed(emoji: String, fraction: Double, index: Int, seed: String) -> Event {
        let hash = seed.unicodeScalars.reduce(UInt32(2166136261)) { ($0 ^ $1.value) &* 16777619 }
        let j1 = Double(hash % 1000) / 1000 - 0.5          // -0.5...0.5
        let j2 = Double((hash >> 10) % 1000) / 1000 - 0.5

        let leftSide = index.isMultiple(of: 2)
        let x = leftSide ? 0.18 + j1 * 0.14 : 0.82 + j1 * 0.14
        let rows: [CGFloat] = [0.16, 0.34, 0.52, 0.68]
        let y = rows[index % rows.count] + CGFloat(j2) * 0.06

        return Event(id: index,
                     emoji: emoji,
                     fraction: fraction,
                     x: CGFloat(x), y: y,
                     rotation: j1 * 26,
                     size: 62 + CGFloat((hash >> 20) % 34))
    }
}
