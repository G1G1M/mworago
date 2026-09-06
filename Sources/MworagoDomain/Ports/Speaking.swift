import Foundation

/// 얼마나 늦춰 읽을까.
///
/// **무엇을 읽느냐에 따라 갈린다.** 가나 한 글자는 0.2초쯤이라 기본 속도로는 들었다는
/// 느낌도 없이 지나가는데, 문장을 같은 속도로 늦추면 말투가 통째로 무너진다.
/// 짧은 것에서 듣고 싶은 것은 **한 소리**고, 문장에서 듣고 싶은 것은 **말의 흐름**이다.
///
/// 실제 숫자는 여기 없다. 그것은 합성기가 쓰는 값이라 소리를 내는 쪽이 안다.
public enum SpeechPace: Sendable, Equatable {
    /// 한 소리를 또렷하게. 오십음도의 글자 하나는 **소리 자체를 익히는** 자리라
    /// 가장 느리게 읽는다.
    case kana
    /// 낱말. 소리를 익히는 것이 아니라 **어떻게 들리는지**를 듣는 자리라
    /// 글자 하나보다 빠르다.
    ///
    /// **글자 하나와 한 빠르기였다.** 둘 다 짧다는 이유로 묶어 두었는데, 하는 일이
    /// 다르다 — 하나는 `あ` 가 무슨 소리인지 익히는 것이고 하나는 `大丈夫` 가 실제로
    /// 어떻게 들리는지 아는 것이다. 낱말을 글자 익히는 속도로 읽으면 자막에서 만나는
    /// 그 말과 다른 것이 된다.
    case word
    /// 있는 그대로. 문장은 이어지는 말이라, 늦추면 어디서 끊어 읽는지가 무너진다.
    case sentence

    /// 글자를 보고 빠르기를 고른다.
    ///
    /// **부르는 쪽이 갈래를 몰라도 되게 있다.** 연습 카드에는 낱말도 문장도 담기는데
    /// (문장째 담기), 화면이 그것을 하나하나 갈라 정하면 자리마다 잣대가 달라진다.
    ///
    /// **길이만으로는 못 가른다.** `ぎゅ` 와 `痛い` 는 둘 다 두 글자인데 하나는 한
    /// 소리이고 하나는 낱말이다. 오십음도에 서는 것은 **가나로만 된 한 소리**이므로
    /// 글자의 종류까지 본다 — 한자가 섞이면 그것은 이미 낱말이다.
    ///
    /// 아홉 자를 넘으면 낱말 하나로 보기 어렵다 — `だいじょうぶですか` 가 그 자리다.
    public static func of(_ text: String) -> SpeechPace {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let count = text.count
        if count == 1 && isKana(text.first!) { return .kana }
        // 요음(`ぎゅ`)은 두 글자로 적히지만 한 소리다. 작은 가나가 뒤에 붙은 것만 그렇다.
        if count == 2, let last = text.last,
           text.allSatisfy(isKana), Self.smallKana.contains(last) { return .kana }
        return count >= 9 ? .sentence : .word
    }

    /// 히라가나·가타카나·장음부호인가. 한자와 라틴은 아니다.
    private static func isKana(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { scalar in
            (0x3041...0x309F).contains(scalar.value)      // 히라가나
                || (0x30A0...0x30FF).contains(scalar.value)   // 가타카나(장음부호 포함)
        }
    }

    /// 앞 글자에 붙어 한 소리를 이루는 작은 가나.
    private static let smallKana: Set<Character> = [
        "ゃ", "ゅ", "ょ", "ぁ", "ぃ", "ぅ", "ぇ", "ぉ",
        "ャ", "ュ", "ョ", "ァ", "ィ", "ゥ", "ェ", "ォ",
    ]
}

/// 일본어를 소리 내어 읽는 것.
///
/// **화면이 합성기를 직접 잡지 않게 있다.** 예전에는 소리 단추가 `AVSpeechSynthesizer` 를
/// 들고 있는 전역 enum 을 곧바로 불렀다. 그러면 소리를 내지 않고 화면을 확인할 길이 없고,
/// 소리 내는 방식을 바꾸는 일이 뷰 파일을 고치는 일이 된다.
/// **화면에 매인 자리로 두지 않는다.** 환경 키의 기본값은 화면 밖에서 만들어지므로,
/// 여기에 `@MainActor` 를 걸면 그 기본값을 세울 수 없다. 실제로 말하는 쪽이
/// 제 자리를 지킨다.
public protocol Speaking: Sendable {
    func speak(_ text: String, pace: SpeechPace)
}

public extension Speaking {
    /// 빠르기를 안 주면 **글자를 보고 고른다.** 부르는 자리마다 갈래를 정하면
    /// 잣대가 어긋난다 — 같은 낱말이 화면에 따라 다른 속도로 읽힌다.
    func speak(_ text: String) { speak(text, pace: .of(text)) }
}

/// 아무 소리도 내지 않는다. 미리보기와 화면 확인이 쓴다.
public struct SilentSpeaker: Speaking {
    public init() {}
    public func speak(_ text: String, pace: SpeechPace) {}
}
