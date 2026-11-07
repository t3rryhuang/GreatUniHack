import Foundation

// Nova Explorer avatar: every option comes from a fixed catalogue, so the stylist
// (on-device or the backend's LLM) can only ever pick allowed values.
// The same catalogue is in test-backend/explorer.py.

enum AvatarColour: String, Codable, CaseIterable, Identifiable, Sendable {
    case purple, pink, red, orange, yellow, green, teal, blue, navy, black, white, grey, brown

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var hex: UInt32 {
        switch self {
        case .purple: 0x7B3FC4
        case .pink: 0xE5689B
        case .red: 0xD8343B
        case .orange: 0xEE7A2A
        case .yellow: 0xF2C230
        case .green: 0x3E9B4F
        case .teal: 0x1E9C99
        case .blue: 0x2F7DE1
        case .navy: 0x22325E
        case .black: 0x262626
        case .white: 0xF2F2F2
        case .grey: 0x8C8C8C
        case .brown: 0x7A4E2D
        }
    }
}

enum SkinTone: String, Codable, CaseIterable, Identifiable, Sendable {
    case tone1, tone2, tone3, tone4, tone5, tone6
    var id: String { rawValue }
    var title: String { "Tone \(rawValue.suffix(1))" }

    var hex: UInt32 {
        switch self {
        case .tone1: 0xF6D7C3
        case .tone2: 0xE8B996
        case .tone3: 0xD09B6E
        case .tone4: 0xA8714A
        case .tone5: 0x7C4E30
        case .tone6: 0x4E301E
        }
    }
}

enum HairStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case short, long, curly, bun, buzz, afro, braids
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum TopStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case hoodie, tshirt, jacket, jumper
    var id: String { rawValue }
    var title: String { self == .tshirt ? "T-shirt" : rawValue.capitalized }
}

enum ShoeStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case trainers, boots, sliders
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum Accessory: String, Codable, CaseIterable, Identifiable, Sendable {
    case none, glasses, cap, beanie, headphones
    var id: String { rawValue }
    var title: String { self == .none ? "None" : rawValue.capitalized }
}

struct AvatarLook: Codable, Hashable, Sendable {
    var skin: SkinTone = .tone3
    var hair: HairStyle = .short
    var hairColour: AvatarColour = .brown
    var top: TopStyle = .hoodie
    var topColour: AvatarColour = .purple
    var bottomColour: AvatarColour = .navy
    var shoes: ShoeStyle = .trainers
    var shoeColour: AvatarColour = .white
    var accessory: Accessory = .none

    nonisolated init() {}

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AvatarLook.defaults
        skin = (try? c.decodeIfPresent(SkinTone.self, forKey: .skin)) ?? d.skin
        hair = (try? c.decodeIfPresent(HairStyle.self, forKey: .hair)) ?? d.hair
        hairColour = (try? c.decodeIfPresent(AvatarColour.self, forKey: .hairColour)) ?? d.hairColour
        top = (try? c.decodeIfPresent(TopStyle.self, forKey: .top)) ?? d.top
        topColour = (try? c.decodeIfPresent(AvatarColour.self, forKey: .topColour)) ?? d.topColour
        bottomColour = (try? c.decodeIfPresent(AvatarColour.self, forKey: .bottomColour)) ?? d.bottomColour
        shoes = (try? c.decodeIfPresent(ShoeStyle.self, forKey: .shoes)) ?? d.shoes
        shoeColour = (try? c.decodeIfPresent(AvatarColour.self, forKey: .shoeColour)) ?? d.shoeColour
        accessory = (try? c.decodeIfPresent(Accessory.self, forKey: .accessory)) ?? d.accessory
    }

    nonisolated private static var defaults: (skin: SkinTone, hair: HairStyle, hairColour: AvatarColour, top: TopStyle, topColour: AvatarColour,
                                              bottomColour: AvatarColour, shoes: ShoeStyle, shoeColour: AvatarColour, accessory: Accessory) {
        (.tone3, .short, .brown, .hoodie, .purple, .navy, .trainers, .white, .none)
    }

    func applying(_ patch: AvatarPatch) -> AvatarLook {
        var l = self
        if let v = patch.skin { l.skin = v }
        if let v = patch.hair { l.hair = v }
        if let v = patch.hairColour { l.hairColour = v }
        if let v = patch.top { l.top = v }
        if let v = patch.topColour { l.topColour = v }
        if let v = patch.bottomColour { l.bottomColour = v }
        if let v = patch.shoes { l.shoes = v }
        if let v = patch.shoeColour { l.shoeColour = v }
        if let v = patch.accessory { l.accessory = v }
        return l
    }

    /// One plain-English line, for VoiceOver and Remi.
    var summary: String {
        "\(hairColour.title.lowercased()) \(hair.title.lowercased()) hair, \(topColour.title.lowercased()) \(top.title.lowercased()), \(bottomColour.title.lowercased()) trousers, \(shoeColour.title.lowercased()) \(shoes.title.lowercased())"
            + (accessory == .none ? "" : ", \(accessory.title.lowercased())")
    }
}

/// A change to the avatar. Every field is optional; unknown values are dropped when decoding.
struct AvatarPatch: Codable, Hashable, Sendable {
    var skin: SkinTone?
    var hair: HairStyle?
    var hairColour: AvatarColour?
    var top: TopStyle?
    var topColour: AvatarColour?
    var bottomColour: AvatarColour?
    var shoes: ShoeStyle?
    var shoeColour: AvatarColour?
    var accessory: Accessory?

    init(skin: SkinTone? = nil, hair: HairStyle? = nil, hairColour: AvatarColour? = nil, top: TopStyle? = nil, topColour: AvatarColour? = nil,
         bottomColour: AvatarColour? = nil, shoes: ShoeStyle? = nil, shoeColour: AvatarColour? = nil, accessory: Accessory? = nil) {
        self.skin = skin; self.hair = hair; self.hairColour = hairColour; self.top = top; self.topColour = topColour
        self.bottomColour = bottomColour; self.shoes = shoes; self.shoeColour = shoeColour; self.accessory = accessory
    }

    /// Lenient decoding: a value outside the catalogue becomes nil instead of failing the whole patch.
    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        skin = try? c.decodeIfPresent(SkinTone.self, forKey: .skin)
        hair = try? c.decodeIfPresent(HairStyle.self, forKey: .hair)
        hairColour = try? c.decodeIfPresent(AvatarColour.self, forKey: .hairColour)
        top = try? c.decodeIfPresent(TopStyle.self, forKey: .top)
        topColour = try? c.decodeIfPresent(AvatarColour.self, forKey: .topColour)
        bottomColour = try? c.decodeIfPresent(AvatarColour.self, forKey: .bottomColour)
        shoes = try? c.decodeIfPresent(ShoeStyle.self, forKey: .shoes)
        shoeColour = try? c.decodeIfPresent(AvatarColour.self, forKey: .shoeColour)
        accessory = try? c.decodeIfPresent(Accessory.self, forKey: .accessory)
    }

    var isEmpty: Bool { self == AvatarPatch() }
}

struct StylistTurn: Codable, Hashable, Sendable {
    let role: String
    let text: String
}

struct StylistReply: Hashable, Sendable {
    let text: String
    let patch: AvatarPatch
    /// True when the player sounds happy with the look.
    let suggestsConfirm: Bool
}

/// Safety for the stylist chat (mirrored server-side in explorer.py).
/// Input: trimmed to 200 characters; emails, phone numbers, postcodes and links are blocked.
/// Output: at most 240 characters, no links, and only catalogue values in the patch.
enum StylistGuard {
    static let maxInput = 200
    static let maxReply = 240
    static let privacyReply = "Let's keep personal details private. Tell me about colours and styles instead!"

    static func cleanInput(_ text: String) -> String {
        String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxInput))
    }

    /// True if the text looks like it contains personal details.
    static func containsPersonalInfo(_ text: String) -> Bool {
        let patterns = [
            #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,           // email
            #"(\+?44|0)\s?\d[\d\s]{8,}"#,                          // UK phone
            #"\b[A-Z]{1,2}\d[A-Z\d]?\s*\d[A-Z]{2}\b"#,             // UK postcode
            #"https?://|www\."#                                    // links
        ]
        return patterns.contains { text.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil }
    }

    static func cleanReply(_ text: String) -> String {
        var t = text.replacingOccurrences(of: #"https?://\S+|www\.\S+"#, with: "", options: .regularExpression)
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.count > maxReply { t = String(t.prefix(maxReply - 1)) + "…" }
        return t.isEmpty ? "Looking good! Anything else you'd like to change?" : t
    }
}

/// Remi's on-device brain: keyword rules (used offline and as the backend's fallback).
enum StylistRules {
    static let greeting = "Hi, I'm Remi, the stylist here at the Nancy Rothwell Building! Tell me how you want to look: hair, top, trousers, shoes or a hat."
    static let suggestions = ["Purple hoodie", "Curly black hair", "Blue jacket", "Glasses", "Long pink hair", "White trainers", "Surprise me"]

    static func reply(to raw: String, current: AvatarLook, seed: Int = 0) -> StylistReply {
        let text = StylistGuard.cleanInput(raw)
        if StylistGuard.containsPersonalInfo(text) {
            return StylistReply(text: StylistGuard.privacyReply, patch: AvatarPatch(), suggestsConfirm: false)
        }
        let q = " " + text.lowercased() + " "
        if ["looks good", "done", "perfect", "that's it", "thats it", "i'm happy", "im happy", "love it"].contains(where: q.contains) {
            return StylistReply(text: "Love it! Tap 'This is me' when you're ready to explore Manchester.", patch: AvatarPatch(), suggestsConfirm: true)
        }
        if q.contains("surprise") {
            var rng = MockDataFactory.SeededGenerator(seed: UInt64(abs(seed) + 7))
            func pick<T: CaseIterable>(_: T.Type) -> T { let all = Array(T.allCases); return all[Int.random(in: 0..<all.count, using: &rng)] }
            let patch = AvatarPatch(hair: pick(HairStyle.self), hairColour: pick(AvatarColour.self), top: pick(TopStyle.self),
                                    topColour: pick(AvatarColour.self), bottomColour: pick(AvatarColour.self), accessory: pick(Accessory.self))
            return StylistReply(text: "Ta-da! A brand new look. Want to change anything?", patch: patch, suggestsConfirm: false)
        }

        var patch = AvatarPatch()
        func colour(before words: [String]) -> AvatarColour? {
            for colour in AvatarColour.allCases {
                for word in words where q.contains(" \(colour.rawValue) \(word)") || q.contains(" \(colour.rawValue)-\(word)") { return colour }
            }
            return nil
        }
        let hairWords = ["hair"] + HairStyle.allCases.map(\.rawValue)
        for style in HairStyle.allCases where q.contains(" \(style.rawValue)") && (q.contains("hair") || style == .afro || style == .braids || style == .bun || style == .buzz) {
            patch.hair = style
        }
        if q.contains("long hair") { patch.hair = .long }
        if q.contains("short hair") { patch.hair = .short }
        if let c = colour(before: hairWords) { patch.hairColour = c }
        if q.contains("blonde") || q.contains("blond") { patch.hairColour = .yellow }
        if q.contains("ginger") { patch.hairColour = .orange }

        let topWords: [(String, TopStyle)] = [("hoodie", .hoodie), ("t-shirt", .tshirt), ("tshirt", .tshirt), ("tee", .tshirt), ("jacket", .jacket), ("coat", .jacket), ("jumper", .jumper), ("sweater", .jumper)]
        for (word, style) in topWords where q.contains(word) { patch.top = style }
        if let c = colour(before: topWords.map(\.0) + ["top", "shirt"]) { patch.topColour = c }
        if let c = colour(before: ["trousers", "jeans", "joggers", "shorts", "skirt", "bottoms"]) { patch.bottomColour = c }
        let shoeWords: [(String, ShoeStyle)] = [("trainers", .trainers), ("sneakers", .trainers), ("boots", .boots), ("sliders", .sliders), ("sandals", .sliders)]
        for (word, style) in shoeWords where q.contains(word) { patch.shoes = style }
        if let c = colour(before: shoeWords.map(\.0) + ["shoes"]) { patch.shoeColour = c }
        for item in Accessory.allCases where item != .none && q.contains(item.rawValue) { patch.accessory = item }
        if q.contains("headphone") { patch.accessory = .headphones }
        if q.contains("hat") && patch.accessory == nil { patch.accessory = .beanie }
        if q.contains("no hat") || q.contains("no glasses") || q.contains("nothing on my head") { patch.accessory = Accessory.none }
        if q.contains("darker skin") { patch.skin = SkinTone.allCases[min(5, (SkinTone.allCases.firstIndex(of: current.skin) ?? 2) + 1)] }
        if q.contains("lighter skin") { patch.skin = SkinTone.allCases[max(0, (SkinTone.allCases.firstIndex(of: current.skin) ?? 2) - 1)] }

        // A colour on its own ("make it green") goes on the top.
        if patch.isEmpty, let lone = AvatarColour.allCases.first(where: { q.contains(" \($0.rawValue) ") }) { patch.topColour = lone }

        guard !patch.isEmpty else {
            return StylistReply(text: "I can change your hair, top, trousers, shoes and accessories. Try 'blue hoodie and curly hair'.", patch: patch, suggestsConfirm: false)
        }
        let next = current.applying(patch)
        return StylistReply(text: "Done: \(next.summary). What do you think?", patch: patch, suggestsConfirm: false)
    }
}
