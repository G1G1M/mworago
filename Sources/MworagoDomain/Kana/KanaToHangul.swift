import Foundation

/// 가나를 한글 음차로 옮긴다. `Transliterator`의 반대 방향이다.
///
/// 이쪽은 답이 하나다. 한국어 화자가 일본어를 한글로 적는 데는 굳어진 관행이 있기 때문이다.
/// - 청음은 격음으로(`か`→카), 탁음은 평음으로(`が`→가) 적어 둘을 가른다
/// - `ぱ`행은 촉음·발음 뒤에서만 경음(`せんぱい`→센빠이), 그 밖에는 격음(`ピアノ`→피아노).
///   일본 고유어에서 `ぱ`행은 `っ`·`ん` 뒤에만 나타나므로, 다른 자리에 오면 대개 외래어다
/// - 장음은 **버린다** (`だいじょうぶ`→다이죠부). 한국어에 장음 표기가 없다
/// - 촉음 `っ`은 앞 음절 받침 ㅅ, 발음 `ん`은 받침 ㄴ
///
/// 이 방향은 **정보를 잃는다.** 되돌리는 쪽(`Transliterator`)이 그 손실을 복구해야 하므로,
/// 여기서 만든 음차는 그 복구력을 재는 시험 문제가 된다.
public enum KanaToHangul {

    // 한글 자모의 유니코드 배열 순서. 조합에 쓸 색인이다.
    private static let 초성_ㄱ = 0, 초성_ㄴ = 2, 초성_ㄷ = 3, 초성_ㄹ = 5, 초성_ㅁ = 6
    private static let 초성_ㅂ = 7, 초성_ㅃ = 8, 초성_ㅅ = 9, 초성_ㅇ = 11, 초성_ㅈ = 12
    private static let 초성_ㅊ = 14, 초성_ㅋ = 15, 초성_ㅌ = 16, 초성_ㅍ = 17, 초성_ㅎ = 18

    private static let 중성_ㅏ = 0, 중성_ㅑ = 2, 중성_ㅔ = 5, 중성_ㅗ = 8, 중성_ㅘ = 9
    private static let 중성_ㅛ = 12, 중성_ㅜ = 13, 중성_ㅝ = 14, 중성_ㅞ = 15, 중성_ㅟ = 16
    private static let 중성_ㅠ = 17, 중성_ㅡ = 18, 중성_ㅣ = 20

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
        // 기본은 격음. 촉음·발음 뒤에서만 경음으로 바꾼다 (아래 transliterate 참고)
        "ぱ": (초성_ㅍ, 중성_ㅏ), "ぴ": (초성_ㅍ, 중성_ㅣ), "ぷ": (초성_ㅍ, 중성_ㅜ),
        "ぺ": (초성_ㅍ, 중성_ㅔ), "ぽ": (초성_ㅍ, 중성_ㅗ),

        "ま": (초성_ㅁ, 중성_ㅏ), "み": (초성_ㅁ, 중성_ㅣ), "む": (초성_ㅁ, 중성_ㅜ),
        "め": (초성_ㅁ, 중성_ㅔ), "も": (초성_ㅁ, 중성_ㅗ),

        "や": (초성_ㅇ, 중성_ㅑ), "ゆ": (초성_ㅇ, 중성_ㅠ), "よ": (초성_ㅇ, 중성_ㅛ),

        "ら": (초성_ㄹ, 중성_ㅏ), "り": (초성_ㄹ, 중성_ㅣ), "る": (초성_ㄹ, 중성_ㅜ),
        "れ": (초성_ㄹ, 중성_ㅔ), "ろ": (초성_ㄹ, 중성_ㅗ),

        "わ": (초성_ㅇ, 중성_ㅘ), "を": (초성_ㅇ, 중성_ㅗ),   // 조사 を는 "오"로 들린다

        // **표에 없는 가나는 음차에 그대로 남는다.** 화면에 일본어가 섞이므로
        // 안 쓰는 글자라도 자리를 비워 두지 않는다.
        "ゐ": (초성_ㅇ, 중성_ㅣ), "ゑ": (초성_ㅇ, 중성_ㅔ),   // 현대에 안 쓰는 옛 가나
        "ゔ": (초성_ㅂ, 중성_ㅜ),                            // ヴ. 외래어의 v — ば행으로 적는다
        "ゕ": (초성_ㅋ, 중성_ㅏ), "ゖ": (초성_ㅋ, 중성_ㅔ),
    ]

    /// 뒤에 오는 う를 장음으로 흡수하는 중성들. ょ·ゅ는 요음이지만 각각 o단·u단이다.
    private static let longVowelBases: Set<Int> = [중성_ㅗ, 중성_ㅜ, 중성_ㅛ, 중성_ㅠ]

    // MARK: 작은 가나
    //
    // **합치지 못하면 음차에 일본어가 그대로 남는다.** `プロジェクト` 가 `푸로지ぇ쿠토` 로
    // 적혔다. 사전의 읽기 265,528개 중 **15,427개(5.8%)** 에 작은 모음이 들어 있다 —
    // `ティーシャツ` · `アーティスト` · `チェック` 처럼 애니에 흔한 외래어들이다.

    /// 요음의 작은 가나 → 중성. **앞 글자가 어느 단이든 이 값이다.**
    /// `きゃ` 는 캬이고 `でゅ` 는 듀다 — ゅ 가 곧 ㅠ 다.
    private static let smallYoon: [Character: Int] = [
        "ゃ": 중성_ㅑ, "ゅ": 중성_ㅠ, "ょ": 중성_ㅛ, "ゎ": 중성_ㅘ,
    ]

    /// 작은 모음 → (평모음 중성, w 계열 중성).
    ///
    /// 어느 쪽을 쓰는지는 **앞 글자**가 정한다. `て` + `ぃ` 는 티이고 `ふ` + `ぁ` 는 화다 —
    /// う단 몇 글자만 반모음이 살아 있고, 나머지는 앞 자음에 모음만 갈아 끼운다.
    private static let smallVowels: [Character: (plain: Int, w: Int)] = [
        "ぁ": (중성_ㅏ, 중성_ㅘ), "ぃ": (중성_ㅣ, 중성_ㅟ), "ぅ": (중성_ㅜ, 중성_ㅜ),
        "ぇ": (중성_ㅔ, 중성_ㅞ), "ぉ": (중성_ㅗ, 중성_ㅝ),
    ]

    /// 작은 모음 앞에서 반모음이 남는 글자.
    ///
    /// **이 넷뿐이다.** `ファ`(화) · `ウォ`(워) · `クァ`(콰) · `グァ`(과) 는 앞 자음에
    /// 반모음이 붙어 들리는데, 같은 う단이라도 `ツァ` 는 차이고 `ヴァ` 는 바다.
    /// 단으로 가르면 그 둘까지 쓸어 담으므로 글자로 적는다.
    private static let glideBefore: Set<Character> = ["う", "ふ", "く", "ぐ"]

    /// 앞에 붙을 것이 없이 홀로 선 작은 가나. 큰 글자로 적은 것과 같이 본다.
    private static let smallAlone: [Character: Character] = [
        "ぁ": "あ", "ぃ": "い", "ぅ": "う", "ぇ": "え", "ぉ": "お",
        "ゃ": "や", "ゅ": "ゆ", "ょ": "よ", "ゎ": "わ",
    ]

    // MARK: 조사로 쓰인 は·へ
    //
    // **일본어에서 표기와 발음이 어긋나는 낱말은 셋뿐이다** — `は`(와) · `へ`(에) ·
    // `を`(오). 그중 `を` 는 위의 표에서도 이미 "오"라 갈릴 것이 없다.
    //
    // 찾을 때는 `Transliterator.particleSpellings` 가 그 사이를 열어 준다 —
    // `와` 를 친 사람에게 `は` 를 후보로 내준다. **보여 줄 때 닫지 않으면**
    // `와타시와` 를 친 사람의 카드에 "하"가 적힌다. 치지도 않았고 들리지도 않는 소리다.

    /// 조사로 쓰였을 때만 표기와 다르게 읽히는 가나.
    ///
    /// **글자 하나에만 걸린다.** 조사는 조각 하나로 홀로 서므로 이것으로 닿고,
    /// 여러 자를 통째로 바꾸려 들면 안 되는 자리까지 손댄다.
    public static let particleSounds: [String: String] = ["は": "와", "へ": "에"]

    /// 조사인지까지 헤아린 음차.
    ///
    /// **갈리는 것은 품사이지 글자가 아니다.** 가나표의 `は` 도, 낱말 `葉`(잎)의
    /// 읽기 `は` 도 "하"가 맞다. 그래서 조사임을 아는 자리에서만 `asParticle` 을 준다.
    public static func transliterate(_ kana: String, asParticle: Bool) -> String {
        if asParticle, let sound = particleSounds[kana] { return sound }
        return transliterate(kana)
    }

    public static func transliterate(_ kana: String) -> String {
        let normalized = KanaTable.toHiragana(kana)
        var result = ""
        var pending: (initial: Int, medial: Int)?   // 아직 받침이 붙을 수 있는 음절
        var previousFinal: Int?                     // 직전 음절에 붙은 받침

        func flush() {
            if let p = pending { result.append(syllable(p.initial, p.medial, 종성_없음)) }
            pending = nil
            previousFinal = nil
        }
        func flushWithFinal(_ final: Int) {
            if let p = pending {
                result.append(syllable(p.initial, p.medial, final))
                pending = nil
                previousFinal = final
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

            // **여기까지 온 작은 가나는 붙을 데가 없던 것이다** — 앞 글자가 있었으면
            // 그 글자를 읽을 때 이미 합쳐졌다. 큰 글자로 적은 것과 같이 본다.
            let letter = smallAlone[character] ?? character
            guard var (initial, medial) = table[letter] else {
                flush()
                result.append(letter)   // 가나가 아니면 그대로
                index = next
                continue
            }

            // ぱ행은 っ·ん 뒤에서만 경음이 된다. 센빠이·잇빠이는 그래서 경음이고,
            // 피아노처럼 그 밖의 자리에 오는 것은 외래어라 격음으로 적는다.
            if initial == 초성_ㅍ, previousFinal == 종성_ㅅ || previousFinal == 종성_ㄴ {
                initial = 초성_ㅃ
            }

            // **뒤따르는 작은 가나는 이 글자와 합친다.** 요음이든 외래어의 확장음이든
            // 앞 글자의 초성을 그대로 두고 중성만 갈아 끼우는 한 가지 일이다
            // (`しょ`→쇼 · `じぇ`→제 · `てぃ`→티 · `ふぁ`→화).
            var advance = next
            if next < normalized.endIndex {
                let following = normalized[next]
                if let yoon = smallYoon[following] {
                    medial = yoon
                    advance = normalized.index(after: next)
                } else if let small = smallVowels[following] {
                    medial = glideBefore.contains(letter) ? small.w : small.plain
                    advance = normalized.index(after: next)
                }
            }

            // 장음은 버린다. お단·う단 뒤의 う만 해당하고, え단 뒤 い는 남긴다 (센세이).
            // 요음 ょ·ゅ도 각각 o단·u단이다 — じょう가 "죠우"가 되면 안 된다
            if let p = pending, letter == "う", longVowelBases.contains(p.medial) {
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

    private static func syllable(_ initial: Int, _ medial: Int, _ final: Int) -> Character {
        Character(Unicode.Scalar(0xAC00 + initial * 588 + medial * 28 + final)!)
    }
}
