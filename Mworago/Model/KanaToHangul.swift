import Foundation

/// 가나를 한글 음차로 옮긴다. `Transliterator`의 반대 방향이다.
///
/// 이쪽은 답이 하나다. 한국어 화자가 일본어를 한글로 적는 데는 굳어진 관행이 있기 때문이다.
/// - 청음은 격음으로(`か`→카), 탁음은 평음으로(`が`→가) 적어 둘을 가른다
/// - `ぱ`행은 경음(`ぱ`→빠)
/// - 장음은 **버린다** (`だいじょうぶ`→다이죠부). 한국어에 장음 표기가 없다
/// - 촉음 `っ`은 앞 음절 받침 ㅅ, 발음 `ん`은 받침 ㄴ
///
/// 이 방향은 **정보를 잃는다.** 되돌리는 쪽(`Transliterator`)이 그 손실을 복구해야 하므로,
/// 여기서 만든 음차는 그 복구력을 재는 시험 문제가 된다.
public enum KanaToHangul {

    // 한글 자모의 유니코드 배열 순서. 조합에 쓸 색인이다.
    private static let 초성_ㄱ = 0, 초성_ㄴ = 2, 초성_ㄷ = 3, 초성_ㄹ = 5, 초성_ㅁ = 6
    private static let 초성_ㅂ = 7, 초성_ㅃ = 8, 초성_ㅅ = 9, 초성_ㅇ = 11, 초성_ㅈ = 12
    private static let 초성_ㅊ = 14, 초성_ㅋ = 15, 초성_ㅌ = 16, 초성_ㅎ = 18

    private static let 중성_ㅏ = 0, 중성_ㅑ = 2, 중성_ㅔ = 5, 중성_ㅗ = 8, 중성_ㅘ = 9
    private static let 중성_ㅛ = 12, 중성_ㅜ = 13, 중성_ㅠ = 17, 중성_ㅡ = 18, 중성_ㅣ = 20

    private static let 종성_없음 = 0, 종성_ㄴ = 4, 종성_ㅅ = 19

    /// 가나 하나 → (초성, 중성).
    private static let table: [Character: (Int, Int)] = [
        "あ": (초성_ㅇ, 중성_ㅏ), "い": (초성_ㅇ, 중성_ㅣ), "う": (초성_ㅇ, 중성_ㅜ),
        "え": (초성_ㅇ, 중성_ㅔ), "お": (초성_ㅇ, 중성_ㅗ),

        "か": (초성_ㅋ, 중성_ㅏ), "き": (초성_ㅋ, 중성_ㅣ), "く": (초성_ㅋ, 중성_ㅜ),
        "け": (초성_ㅋ, 중성_ㅔ), "こ": (초성_ㅋ, 중성_ㅗ),
        "が": (초성_ㄱ, 중성_ㅏ), "ぎ": (초성_ㄱ, 중성_ㅣ), "ぐ": (초성_ㄱ, 중성_ㅜ),
        "げ": (초성_ㄱ, 중성_ㅔ), "ご": (초성_ㄱ, 중성_ㅗ),

        // す·つ·ず는 ㅡ로 적는다. "스고이"·"츠카레타"
        "さ": (초성_ㅅ, 중성_ㅏ), "し": (초성_ㅅ, 중성_ㅣ), "す": (초성_ㅅ, 중성_ㅡ),
        "せ": (초성_ㅅ, 중성_ㅔ), "そ": (초성_ㅅ, 중성_ㅗ),
        "ざ": (초성_ㅈ, 중성_ㅏ), "じ": (초성_ㅈ, 중성_ㅣ), "ず": (초성_ㅈ, 중성_ㅡ),
        "ぜ": (초성_ㅈ, 중성_ㅔ), "ぞ": (초성_ㅈ, 중성_ㅗ),

        // ち·つ만 ㅊ이다. た·て·と는 ㅌ
        "た": (초성_ㅌ, 중성_ㅏ), "ち": (초성_ㅊ, 중성_ㅣ), "つ": (초성_ㅊ, 중성_ㅡ),
        "て": (초성_ㅌ, 중성_ㅔ), "と": (초성_ㅌ, 중성_ㅗ),
        "だ": (초성_ㄷ, 중성_ㅏ), "ぢ": (초성_ㅈ, 중성_ㅣ), "づ": (초성_ㅈ, 중성_ㅡ),
        "で": (초성_ㄷ, 중성_ㅔ), "ど": (초성_ㄷ, 중성_ㅗ),

        "な": (초성_ㄴ, 중성_ㅏ), "に": (초성_ㄴ, 중성_ㅣ), "ぬ": (초성_ㄴ, 중성_ㅜ),
        "ね": (초성_ㄴ, 중성_ㅔ), "の": (초성_ㄴ, 중성_ㅗ),

        "は": (초성_ㅎ, 중성_ㅏ), "ひ": (초성_ㅎ, 중성_ㅣ), "ふ": (초성_ㅎ, 중성_ㅜ),
        "へ": (초성_ㅎ, 중성_ㅔ), "ほ": (초성_ㅎ, 중성_ㅗ),
        "ば": (초성_ㅂ, 중성_ㅏ), "び": (초성_ㅂ, 중성_ㅣ), "ぶ": (초성_ㅂ, 중성_ㅜ),
        "べ": (초성_ㅂ, 중성_ㅔ), "ぼ": (초성_ㅂ, 중성_ㅗ),
        "ぱ": (초성_ㅃ, 중성_ㅏ), "ぴ": (초성_ㅃ, 중성_ㅣ), "ぷ": (초성_ㅃ, 중성_ㅜ),
        "ぺ": (초성_ㅃ, 중성_ㅔ), "ぽ": (초성_ㅃ, 중성_ㅗ),

        "ま": (초성_ㅁ, 중성_ㅏ), "み": (초성_ㅁ, 중성_ㅣ), "む": (초성_ㅁ, 중성_ㅜ),
        "め": (초성_ㅁ, 중성_ㅔ), "も": (초성_ㅁ, 중성_ㅗ),

        "や": (초성_ㅇ, 중성_ㅑ), "ゆ": (초성_ㅇ, 중성_ㅠ), "よ": (초성_ㅇ, 중성_ㅛ),

        "ら": (초성_ㄹ, 중성_ㅏ), "り": (초성_ㄹ, 중성_ㅣ), "る": (초성_ㄹ, 중성_ㅜ),
        "れ": (초성_ㄹ, 중성_ㅔ), "ろ": (초성_ㄹ, 중성_ㅗ),

        "わ": (초성_ㅇ, 중성_ㅘ), "を": (초성_ㅇ, 중성_ㅗ),   // 조사 を는 "오"로 들린다
    ]

    /// 뒤에 오는 う를 장음으로 흡수하는 중성들. ょ·ゅ는 요음이지만 각각 o단·u단이다.
    private static let longVowelBases: Set<Int> = [중성_ㅗ, 중성_ㅜ, 중성_ㅛ, 중성_ㅠ]

    /// 작은 가나 → 요음의 중성
    private static let smallVowels: [Character: Int] = [
        "ゃ": 중성_ㅑ, "ゅ": 중성_ㅠ, "ょ": 중성_ㅛ,
    ]

    public static func transliterate(_ kana: String) -> String {
        let normalized = katakanaToHiragana(kana)
        var result = ""
        var pending: (initial: Int, medial: Int)?   // 아직 받침이 붙을 수 있는 음절

        func flush() {
            if let p = pending { result.append(syllable(p.initial, p.medial, 종성_없음)) }
            pending = nil
        }
        func flushWithFinal(_ final: Int) {
            if let p = pending {
                result.append(syllable(p.initial, p.medial, final))
                pending = nil
            }
        }

        var index = normalized.startIndex
        while index < normalized.endIndex {
            let character = normalized[index]
            let next = normalized.index(after: index)

            switch character {
            case "ん":
                flushWithFinal(종성_ㄴ)
                index = next
                continue
            case "っ":
                flushWithFinal(종성_ㅅ)
                index = next
                continue
            case "ー":
                index = next   // 장음 부호는 버린다
                continue
            default: break
            }

            guard var (initial, medial) = table[character] else {
                flush()
                result.append(character)   // 가나가 아니면 그대로
                index = next
                continue
            }

            // 뒤따르는 작은 가나가 있으면 요음으로 합친다 (しょ → 쇼)
            var advance = next
            if medial == 중성_ㅣ, next < normalized.endIndex, let small = smallVowels[normalized[next]] {
                medial = small
                advance = normalized.index(after: next)
            }

            // 장음은 버린다. お단·う단 뒤의 う만 해당하고, え단 뒤 い는 남긴다 (센세이).
            // 요음 ょ·ゅ도 각각 o단·u단이다 — じょう가 "죠우"가 되면 안 된다
            if let p = pending, character == "う", longVowelBases.contains(p.medial) {
                index = advance
                continue
            }

            flush()
            pending = (initial, medial)
            index = advance
        }
        flush()
        return result
    }

    /// 가타카나를 히라가나로. 두 표는 같은 순서로 배열돼 있어 오프셋만 빼면 된다.
    private static func katakanaToHiragana(_ text: String) -> String {
        String(String.UnicodeScalarView(text.unicodeScalars.map { scalar in
            (0x30A1...0x30F6).contains(scalar.value)
                ? Unicode.Scalar(scalar.value - 0x60)! : scalar
        }))
    }

    private static func syllable(_ initial: Int, _ medial: Int, _ final: Int) -> Character {
        Character(Unicode.Scalar(0xAC00 + initial * 588 + medial * 28 + final)!)
    }
}
