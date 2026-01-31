import Foundation
import CryptoKit

/// Configurable password generator with secure random generation.
final class PasswordGenerator: Sendable {
    // MARK: - Singleton

    static let shared = PasswordGenerator()

    // MARK: - Configuration

    struct Configuration: Codable, Hashable, Sendable {
        var length: Int = 20
        var includeUppercase: Bool = true
        var includeLowercase: Bool = true
        var includeNumbers: Bool = true
        var includeSymbols: Bool = true
        var excludeAmbiguous: Bool = false
        var customSymbols: String = "!@#$%^&*()_+-=[]{}|;:,.<>?"

        // Validation
        var isValid: Bool {
            length >= 4 &&
            length <= 128 &&
            (includeUppercase || includeLowercase || includeNumbers || includeSymbols)
        }

        // Character sets
        static let uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        static let lowercase = "abcdefghijklmnopqrstuvwxyz"
        static let numbers = "0123456789"
        static let defaultSymbols = "!@#$%^&*()_+-=[]{}|;:,.<>?"
        static let ambiguousChars = "0O1lI"

        var characterPool: String {
            var pool = ""

            if includeUppercase {
                pool += Self.uppercase
            }

            if includeLowercase {
                pool += Self.lowercase
            }

            if includeNumbers {
                pool += Self.numbers
            }

            if includeSymbols {
                pool += customSymbols.isEmpty ? Self.defaultSymbols : customSymbols
            }

            if excludeAmbiguous {
                pool = pool.filter { !Self.ambiguousChars.contains($0) }
            }

            return pool
        }
    }

    // MARK: - Password Strength

    enum Strength: Int, Comparable, Sendable {
        case veryWeak = 0
        case weak = 1
        case fair = 2
        case strong = 3
        case veryStrong = 4

        static func < (lhs: Strength, rhs: Strength) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var label: String {
            switch self {
            case .veryWeak: return "Very weak"
            case .weak: return "Weak"
            case .fair: return "Fair"
            case .strong: return "Strong"
            case .veryStrong: return "Very strong"
            }
        }

        var color: String {
            switch self {
            case .veryWeak: return "red"
            case .weak: return "orange"
            case .fair: return "yellow"
            case .strong: return "green"
            case .veryStrong: return "blue"
            }
        }
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Generation

    /// Generates a password using the provided configuration.
    func generate(with config: Configuration = Configuration()) -> String {
        guard config.isValid else {
            return generate() // Fall back to defaults
        }

        let pool = Array(config.characterPool)
        guard !pool.isEmpty else {
            return generate() // Fall back to defaults
        }

        var password = ""
        var randomBytes = [UInt8](repeating: 0, count: config.length * 2)

        // Use SecRandomCopyBytes for cryptographically secure randomness
        let result = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        guard result == errSecSuccess else {
            // Fallback to less secure random if secure fails
            for _ in 0..<config.length {
                if let char = pool.randomElement() {
                    password.append(char)
                }
            }
            return password
        }

        // Use random bytes to select characters
        for i in 0..<config.length {
            let randomValue = (Int(randomBytes[i * 2]) << 8) | Int(randomBytes[i * 2 + 1])
            let index = randomValue % pool.count
            password.append(pool[index])
        }

        // Ensure at least one character from each required set
        password = ensureRequirements(password: password, config: config, pool: pool)

        return password
    }

    /// Generates a passphrase using random words.
    func generatePassphrase(
        wordCount: Int = 4,
        separator: String = "-",
        capitalize: Bool = true
    ) -> String {
        let words = selectRandomWords(count: wordCount)

        let processed = words.map { word -> String in
            if capitalize {
                return word.capitalized
            }
            return word
        }

        return processed.joined(separator: separator)
    }

    // MARK: - Strength Evaluation

    /// Evaluates the strength of a password.
    func evaluateStrength(_ password: String) -> Strength {
        let length = password.count

        // Check for empty or very short passwords
        if length < 4 {
            return .veryWeak
        }

        var score = 0

        // Length scoring
        if length >= 8 { score += 1 }
        if length >= 12 { score += 1 }
        if length >= 16 { score += 1 }
        if length >= 20 { score += 1 }

        // Character variety
        let hasUppercase = password.contains { $0.isUppercase }
        let hasLowercase = password.contains { $0.isLowercase }
        let hasNumbers = password.contains { $0.isNumber }
        let hasSymbols = password.contains { !$0.isLetter && !$0.isNumber }

        let varietyCount = [hasUppercase, hasLowercase, hasNumbers, hasSymbols].filter { $0 }.count
        score += varietyCount

        // Penalize common patterns
        if containsSequence(password) {
            score -= 1
        }

        if containsRepeats(password) {
            score -= 1
        }

        // Map score to strength
        switch score {
        case ...2:
            return .veryWeak
        case 3:
            return .weak
        case 4...5:
            return .fair
        case 6...7:
            return .strong
        default:
            return .veryStrong
        }
    }

    /// Calculates entropy in bits.
    func calculateEntropy(_ password: String) -> Double {
        guard !password.isEmpty else { return 0 }

        let hasUppercase = password.contains { $0.isUppercase }
        let hasLowercase = password.contains { $0.isLowercase }
        let hasNumbers = password.contains { $0.isNumber }
        let hasSymbols = password.contains { !$0.isLetter && !$0.isNumber }

        var poolSize = 0
        if hasUppercase { poolSize += 26 }
        if hasLowercase { poolSize += 26 }
        if hasNumbers { poolSize += 10 }
        if hasSymbols { poolSize += 32 }

        guard poolSize > 0 else { return 0 }

        return Double(password.count) * log2(Double(poolSize))
    }

    // MARK: - Private Helpers

    private func ensureRequirements(
        password: String,
        config: Configuration,
        pool: [Character]
    ) -> String {
        var chars = Array(password)

        // Helper to get random char from a string
        func randomChar(from set: String) -> Character? {
            var bytes = [UInt8](repeating: 0, count: 1)
            guard SecRandomCopyBytes(kSecRandomDefault, 1, &bytes) == errSecSuccess else {
                return set.randomElement()
            }
            let index = Int(bytes[0]) % set.count
            return set[set.index(set.startIndex, offsetBy: index)]
        }

        // Ensure at least one uppercase if required
        if config.includeUppercase && !chars.contains(where: { $0.isUppercase }) {
            if let char = randomChar(from: Configuration.uppercase) {
                chars[0] = char
            }
        }

        // Ensure at least one lowercase if required
        if config.includeLowercase && !chars.contains(where: { $0.isLowercase }) {
            if let char = randomChar(from: Configuration.lowercase), chars.count > 1 {
                chars[1] = char
            }
        }

        // Ensure at least one number if required
        if config.includeNumbers && !chars.contains(where: { $0.isNumber }) {
            if let char = randomChar(from: Configuration.numbers), chars.count > 2 {
                chars[2] = char
            }
        }

        // Ensure at least one symbol if required
        if config.includeSymbols && !chars.contains(where: { !$0.isLetter && !$0.isNumber }) {
            let symbols = config.customSymbols.isEmpty ? Configuration.defaultSymbols : config.customSymbols
            if let char = randomChar(from: symbols), chars.count > 3 {
                chars[3] = char
            }
        }

        // Shuffle to avoid predictable positions
        return String(shuffleSecurely(chars))
    }

    private func shuffleSecurely(_ array: [Character]) -> [Character] {
        var result = array
        var randomBytes = [UInt8](repeating: 0, count: result.count)

        guard SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes) == errSecSuccess else {
            return result.shuffled() // Fallback
        }

        for i in stride(from: result.count - 1, through: 1, by: -1) {
            let j = Int(randomBytes[i]) % (i + 1)
            if i != j {
                result.swapAt(i, j)
            }
        }

        return result
    }

    private func containsSequence(_ password: String) -> Bool {
        let sequences = [
            "abcdefghijklmnopqrstuvwxyz",
            "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
            "0123456789",
            "qwertyuiop",
            "asdfghjkl",
            "zxcvbnm"
        ]

        let lowercased = password.lowercased()

        for sequence in sequences {
            for i in 0..<(sequence.count - 2) {
                let start = sequence.index(sequence.startIndex, offsetBy: i)
                let end = sequence.index(start, offsetBy: 3)
                let substring = String(sequence[start..<end])

                if lowercased.contains(substring) {
                    return true
                }
            }
        }

        return false
    }

    private func containsRepeats(_ password: String) -> Bool {
        let chars = Array(password)

        for i in 0..<(chars.count - 2) {
            if chars[i] == chars[i + 1] && chars[i + 1] == chars[i + 2] {
                return true
            }
        }

        return false
    }

    private func selectRandomWords(count: Int) -> [String] {
        var words: [String] = []
        var randomBytes = [UInt8](repeating: 0, count: count * 2)

        guard SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes) == errSecSuccess else {
            for _ in 0..<count {
                if let word = Self.wordList.randomElement() {
                    words.append(word)
                }
            }
            return words
        }

        for i in 0..<count {
            let randomValue = (Int(randomBytes[i * 2]) << 8) | Int(randomBytes[i * 2 + 1])
            let index = randomValue % Self.wordList.count
            words.append(Self.wordList[index])
        }

        return words
    }

    // MARK: - Word List

    /// EFF's short word list (subset for demo)
    private static let wordList: [String] = [
        "acid", "acorn", "acre", "acts", "afar", "affix", "aged", "agent",
        "agile", "aging", "agony", "ahead", "aide", "aids", "aim", "ajar",
        "alarm", "album", "alert", "alias", "alibi", "alien", "align", "alike",
        "alive", "alley", "allot", "allow", "alloy", "ally", "alpha", "also",
        "altar", "alter", "amaze", "amber", "amend", "amino", "ample", "amuse",
        "angel", "anger", "angle", "angry", "ankle", "annex", "antic", "anvil",
        "apart", "apex", "apple", "apply", "apron", "aqua", "arbor", "arena",
        "argue", "arise", "armor", "army", "aroma", "array", "arrow", "arson",
        "craft", "cramp", "crane", "crank", "crash", "crate", "crawl", "craze",
        "crazy", "creed", "creek", "creep", "crest", "crisp", "croak", "crock",
        "baker", "badge", "badly", "bagel", "baggy", "baked", "baker", "balmy",
        "bench", "berry", "birth", "bison", "black", "blade", "blame", "blank",
        "blast", "blaze", "bleak", "bleed", "blend", "bless", "blimp", "blind",
        "blink", "bliss", "blitz", "bloat", "block", "blond", "blood", "bloom",
        "blown", "blues", "bluff", "blunt", "blurt", "blush", "board", "boast",
        "dance", "dandy", "darts", "data", "dated", "dawn", "dealt", "death",
        "debit", "debug", "debut", "decal", "decay", "decor", "decoy", "decry",
        "eagle", "earth", "easel", "eaten", "eater", "ebony", "edges", "edict",
        "eerie", "eight", "elbow", "elder", "elect", "elite", "elope", "elude",
        "ember", "empty", "enact", "endow", "enemy", "enjoy", "enter", "entry",
        "equal", "equip", "erase", "erode", "error", "erupt", "essay", "evade",
        "event", "every", "exact", "exalt", "excel", "exile", "exist", "expel",
        "fable", "faced", "facet", "faint", "fairy", "faith", "false", "fancy",
        "fargo", "fatal", "fatty", "fault", "fauna", "favor", "feast", "fence",
        "fever", "fiber", "fifth", "fifty", "fight", "filer", "filth", "final",
        "flame", "flank", "flare", "flash", "flask", "flesh", "flick", "flier",
        "fling", "flint", "float", "flock", "flood", "floor", "flora", "floss",
        "grace", "grade", "grain", "grand", "grant", "grape", "graph", "grasp",
        "grass", "grave", "gravy", "greed", "green", "greet", "grief", "grill",
        "habit", "hairy", "happy", "harsh", "haste", "hasty", "hatch", "haven",
        "heart", "heavy", "hedge", "hefty", "heist", "hello", "herbs", "heron",
        "ivory", "jaunt", "jazzy", "jelly", "jewel", "joint", "joker", "jolly",
        "judge", "juice", "jumbo", "jumpy", "kayak", "kebab", "khaki", "kiosk",
        "label", "labor", "lager", "lance", "large", "laser", "latch", "later",
        "laugh", "layer", "leach", "leafy", "learn", "lease", "least", "leave",
        "macro", "madam", "madly", "magic", "magma", "mango", "manor", "maple",
        "march", "marry", "marsh", "match", "mayor", "meaty", "medal", "media",
        "naked", "nasty", "naval", "nerve", "never", "newer", "newly", "night",
        "ninja", "ninth", "noble", "noise", "north", "notch", "novel", "nudge",
        "oasis", "ocean", "offer", "often", "olive", "omega", "onion", "onset",
        "opera", "opted", "optic", "orbit", "order", "organ", "other", "ought",
        "ounce", "outer", "outdo", "owned", "owner", "oxide", "ozone", "paddy",
        "pagan", "paint", "panda", "panel", "panic", "paper", "party", "pasta",
        "patch", "pause", "peace", "peach", "pearl", "pedal", "penny", "perch",
        "quick", "quiet", "quill", "quilt", "quirk", "quota", "quote", "radar",
        "radio", "raise", "rally", "ramen", "ranch", "rapid", "raven", "reach",
        "react", "ready", "realm", "rebel", "refer", "reign", "relax", "relay",
        "safer", "saint", "salad", "salon", "salsa", "salty", "salve", "sandy",
        "satin", "sauna", "savor", "scale", "scalp", "scant", "scare", "scarf",
        "scene", "scent", "scold", "scoop", "scope", "score", "scorn", "scout",
        "table", "tacky", "taint", "taken", "taker", "tally", "talon", "tamer",
        "tangy", "taper", "tapir", "tardy", "taste", "tasty", "taunt", "teach",
        "ultra", "uncle", "uncut", "under", "undid", "unfit", "unify", "union",
        "unite", "unity", "unlit", "unmet", "until", "upper", "upset", "urban",
        "valid", "valor", "value", "valve", "vapor", "vault", "vegan", "veldt",
        "venue", "verge", "verse", "video", "vigor", "villa", "vinyl", "viola",
        "wacky", "wafer", "wager", "wagon", "waist", "waltz", "waste", "watch",
        "water", "weary", "weave", "wedge", "weigh", "weird", "wheat", "wheel",
        "xerox", "yacht", "yearn", "yeast", "yield", "young", "youth", "zebra",
        "zesty", "zippy", "zones", "abbot", "about", "above", "abuse", "adapt"
    ]
}
