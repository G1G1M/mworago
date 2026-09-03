import Foundation

/// 얼마나 늦춰 읽을까.
///
/// **무엇을 읽느냐에 따라 갈린다.** 가나 한 글자는 0.2초쯤이라 기본 속도로는 들었다는
/// 느낌도 없이 지나가는데, 문장을 같은 속도로 늦추면 말투가 통째로 무너진다.
/// 짧은 것에서 듣고 싶은 것은 **한 소리**고, 문장에서 듣고 싶은 것은 **말의 흐름**이다.
///
/// 실제 숫자는 여기 없다. 그것은 합성기가 쓰는 값이라 소리를 내는 쪽이 안다.
public enum SpeechPace: Sendable {
    /// 한 소리를 또렷하게. 글자 하나와 낱말은 짧아서 기본 속도로는 지나가 버린다.
    case word
    /// 있는 그대로. 문장은 이어지는 말이라, 늦추면 어디서 끊어 읽는지가 무너진다.
    case sentence
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
    /// 대개는 낱말이다. 이 단추가 서는 자리는 낱말 곁이고, 문장은 한 곳뿐이다.
    func speak(_ text: String) { speak(text, pace: .word) }
}

/// 아무 소리도 내지 않는다. 미리보기와 화면 확인이 쓴다.
public struct SilentSpeaker: Speaking {
    public init() {}
    public func speak(_ text: String, pace: SpeechPace) {}
}
