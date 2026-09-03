import AVFoundation
import SwiftUI
import MworagoCore

/// 기기 안의 합성기로 읽는다.
///
/// `AVSpeechSynthesizer` 는 **기기 안에서 말한다** — 서버로 나가지 않으니 요금도
/// 네트워크도 없고, 이 앱이 "아무것도 모으지 않는다"고 적어 둔 것과 어긋나지 않는다.
///
/// **글자 하나에서 시작해 문장까지 왔다.** 처음에는 가나 한 글자를 읽어 주는 것뿐이라
/// `KanaVoice` 였는데, 찾은 낱말도 되살린 문장도 들어 봐야 하는 것은 마찬가지다 —
/// 소리를 듣고 찾아온 사람에게 돌려줄 것도 결국 소리다.
/// **화면에서만 불린다.** 소리 단추의 눌림과 글자 상세의 탭이 전부이고, 둘 다
/// 화면 위의 일이다. 그래서 안쪽 상태를 화면의 자리에서만 만지고(`assumeIsolated`),
/// 타입 자체는 환경 키가 기본값으로 세울 수 있게 열어 둔다.
final class SystemSpeaker: Speaking, @unchecked Sendable {

    /// 합성기는 앱에 하나면 된다. 여럿이면 서로의 말을 끊지 못해 겹쳐 들린다.
    static let shared = SystemSpeaker()

    // 이 둘은 `utter` 안에서만 만진다 — 그 자리가 화면의 자리다.
    private let synth = AVSpeechSynthesizer()
    private var sessionReady = false

    /// 빠르기를 합성기의 숫자로 옮긴다. 뜻(`SpeechPace`)은 코어가 알고,
    /// 그것이 몇인지는 소리를 내는 이 자리가 안다.
    private static func rate(for pace: SpeechPace) -> Float {
        switch pace {
        case .word: AVSpeechUtteranceDefaultSpeechRate * 0.4
        case .sentence: AVSpeechUtteranceDefaultSpeechRate
        }
    }

    /// 소리 낼 자리를 미리 잡아 둔다.
    ///
    /// **말하는 순간에 잡으면 앞머리가 먹힌다.** 세션이 올라오는 짧은 사이에 이미 말이
    /// 시작되는데, 0.2초짜리 소리에서는 그 사이에 거의 다 지나가 버린다.
    ///
    /// `.mixWithOthers` 인 것은 **애니를 보면서 쓰는 앱**이기 때문이다. 소리를
    /// 들으려고 눌렀는데 보던 영상이 멈추면, 얻은 것보다 잃은 것이 크다.
    @MainActor
    private func prepareSession() {
        guard !sessionReady else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers])
        try? session.setActive(true)
        sessionReady = true
    }

    /// 일본어 음성.
    ///
    /// **`nil` 을 그대로 두면 안 된다.** 기기에 ja-JP 가 없을 때 `voice` 가 비면
    /// 시스템 언어(한국어) 음성이 가나를 읽으려 들어 엉뚱한 소리가 난다.
    /// 한 번만 찾고 들고 있는다 — 누를 때마다 음성 목록을 훑을 일이 아니다.
    private static let japanese: AVSpeechSynthesisVoice? =
        AVSpeechSynthesisVoice(language: "ja-JP")
        ?? AVSpeechSynthesisVoice.speechVoices().first { $0.language.hasPrefix("ja") }

    func speak(_ text: String, pace: SpeechPace) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        // 부르는 자리가 전부 화면 위다 — 단추의 눌림과 글자 상세의 탭.
        // 줄을 새로 띄우지 않는 것은 **첫 소리가 밀리면 안 되기** 때문이다.
        // 0.2초짜리 소리에서는 한 틱의 지연도 들린다.
        MainActor.assumeIsolated { self.utter(text, pace: pace) }
    }

    @MainActor
    private func utter(_ text: String, pace: SpeechPace) {
        prepareSession()
        synth.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.japanese
        utterance.rate = Self.rate(for: pace)
        // 앞의 말을 끊고 바로 이어 말하면 첫 소리가 잘린다. 짧은 사이를 두어
        // 세션과 합성기가 준비된 뒤에 말이 시작되게 한다.
        utterance.preUtteranceDelay = 0.08
        synth.speak(utterance)
    }
}

extension EnvironmentValues {
    /// 소리 내어 읽는 자리. 기본은 기기의 합성기다.
    ///
    /// **`@Observable` 이 아니라 환경 키로 둔다.** 소리는 화면이 지켜볼 상태가 아니라
    /// 시키는 일이라, 바뀔 때 화면이 다시 그려질 이유가 없다.
    @Entry var speaker: any Speaking = SystemSpeaker.shared
}
