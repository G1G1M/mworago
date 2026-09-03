import Foundation

/// 일본어 문장에서 낱말 하나와 그 읽기.
public struct JapaneseToken: Sendable, Equatable {
    public let surface: String   // 문장에 나타난 그대로
    public let reading: String   // 히라가나
}

/// 한자가 섞인 일본어 문장을 낱말과 읽기로 나눈다.
///
/// 자막에는 한자만 있고 읽기가 없다. 그래서 자막 코퍼스를 케이스로 쓰려면
/// 읽기를 만들어 내야 하는데, macOS 가 그 일을 이미 할 줄 안다.
///
/// ```
/// 頭が痛い → 頭(あたま) が(が) 痛い(いたい)
/// ```
///
/// `CFStringTokenizer`가 분절과 로마자 읽기를 함께 주고, `CFStringTransform`이
/// 그 로마자를 가나로 되돌린다. 사람이 주석을 단 코퍼스가 아니어도 케이스가 된다.
///
/// 다만 분절 기준은 이 토크나이저의 것이다. 사람이 나눈 Tanaka Corpus 와는
/// 경계가 다를 수 있으므로(`読んだ`를 `読ん`+`だ`로 나눈다), 분절 정답으로 쓸 때는
/// 그 차이를 감안해야 한다.
public enum JapaneseReading {

    public static func analyze(_ text: String) -> [JapaneseToken] {
        guard !text.isEmpty else { return [] }
        // **가나 없는 문장을 걸러 보았으나 재어 보니 손해였다.**
        // JESC 일본어 칸에는 중국어가 섞여 있고, 한자는 중국어에도 쓰이므로 낱말 하나만
        // 보고는 가릴 수 없다. 그래서 토크나이저가 그 한자를 일본어 음으로 읽어
        // 빈도 목록에 싣는다 — 我 가 が 로, 生 이 しぇえんぐ(sheng) 로.
        // 명백한 오염이라 문장에 가나가 없으면 건너뛰게 했더니, 오염은 사라졌는데
        // **성적이 양쪽 다 떨어졌다**(낱말 3위안 147→146 · 분절 30.3%→30.0%).
        // 그 항목들은 순위가 낮아 답을 바꾸지 못하는 반면, 함께 걸러진 짧은 일본어
        // (한자만으로 된 줄)의 손해가 더 컸다. 눈에 거슬리는 것과 해로운 것은 다르다.

        let nsText = text as NSString
        let tokenizer = CFStringTokenizerCreate(nil, text as CFString,
                                                CFRangeMake(0, nsText.length),
                                                kCFStringTokenizerUnitWordBoundary,
                                                Locale(identifier: "ja") as CFLocale)
        var tokens: [JapaneseToken] = []
        while CFStringTokenizerAdvanceToNextToken(tokenizer) != [] {
            let range = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            guard range.length > 0 else { continue }
            let surface = nsText.substring(with: NSRange(location: range.location, length: range.length))
            // 로마자 낱말도 가나로 "읽어" 버린다 (ABC → あぶく). 원문이 일본어여야 한다.
            guard surface.contains(where: isJapanese) else { continue }

            guard let romaji = CFStringTokenizerCopyCurrentTokenAttribute(
                    tokenizer, kCFStringTokenizerAttributeLatinTranscription) as? String,
                  let kana = toHiragana(romaji),
                  // 빈 읽기를 막는다. allSatisfy 는 빈 것에 참이라 그냥 두면
                  // 읽기 없는 낱말이 그대로 통과한다(你好 가 그랬다).
                  !kana.isEmpty,
                  kana.allSatisfy(isKana)
            else { continue }   // 문장부호·로마자·숫자는 읽기가 나오지 않는다

            tokens.append(JapaneseToken(surface: surface, reading: kana))
        }
        return tokens
    }

    /// 헵번식 로마자를 히라가나로. 우리 `KanaTable`은 훈령식이라 표를 따로 두는 대신
    /// 시스템 변환을 쓴다 — `daijoubu` → `だいじょうぶ`.
    private static func toHiragana(_ romaji: String) -> String? {
        let buffer = NSMutableString(string: romaji) as CFMutableString
        guard CFStringTransform(buffer, nil, kCFStringTransformLatinHiragana, false) else { return nil }
        return buffer as String
    }

    static func isKana(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { (0x3041...0x30FF).contains($0.value) }
    }

    /// 가나 또는 CJK 통합 한자
    private static func isJapanese(_ character: Character) -> Bool {
        character.unicodeScalars.contains {
            (0x3041...0x30FF).contains($0.value) || (0x4E00...0x9FFF).contains($0.value)
        }
    }
}
