import Foundation

public final class BurmesePostProcessor {
    public static let shared = BurmesePostProcessor()
    private init() {}

    // Suffixes and particles that attach to the preceding syllable
    private let attachToPrev: Set<String> = [
        "တွေ", "များ", "ကို", "မှာ", "က", "သို့", "ဖြင့်", "နှင့်", "နဲ့",
        "အား", "တွင်", "မှ", "၌", "တယ်", "သည်", "၏", "သော", "၍", "ပြီး",
        "တော့", "နေ", "တဲ့", "တာ", "ပါ", "လိုက်", "ခင်ဗျာ", "ရှင်", "ရှင့်",
        "ခြင်း", "မှု", "ချက်", "ရေး", "ရာ", "စရာ", "ရဲ", "မဲ့", "ဦး", "ရုံ",
        "လျှင်", "ရင်", "လို့", "လည်း", "ပဲ", "ခဲ", "ဦးမည်", "မည်", "ဦးမယ်", "မယ်"
    ]

    // Prefixes that attach to the next syllable
    private let attachToNext: Set<String> = [
        "အ", "မ", "ဒီ", "ထို", "မဟာ"
    ]

    /// Format syllable-spaced Burmese text into natural compound words
    public func format(syllables: String) -> String {
        let tokens = syllables.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return "" }

        var result: [String] = []

        for token in tokens {
            // Check subjoined consonant (ပါဌ်ဆင့် - contains Virama ္ U+1039)
            let isSubjoined = token.contains("\u{1039}")

            if let last = result.last, (isSubjoined || attachToPrev.contains(token) || attachToNext.contains(last)) {
                result[result.count - 1] = last + token
            } else {
                result.append(token)
            }
        }

        return result.joined(separator: " ")
    }
}

