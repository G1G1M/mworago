import SwiftUI
import AVFoundation

/// 일본어를 소리 내어 읽는다.
///
/// `AVSpeechSynthesizer` 는 **기기 안에서 말한다** — 서버로 나가지 않으니 요금도
/// 네트워크도 없고, 이 앱이 "아무것도 모으지 않는다"고 적어 둔 것과 어긋나지 않는다.
///
/// **글자 하나에서 시작해 문장까지 왔다.** 처음에는 가나 한 글자를 읽어 주는 것뿐이라
/// `KanaVoice` 였는데, 찾은 낱말도 되살린 문장도 들어 봐야 하는 것은 마찬가지다 —
/// 소리를 듣고 찾아온 사람에게 돌려줄 것도 결국 소리다.
///
/// **가나 한 글자는 0.2초쯤이다.** `あ` 는 모음 하나라 기본 속도로는 들었다는 느낌도
/// 없이 지나간다. 여기서 들려주는 것은 유창함이 아니라 **한 소리**라서, 늘어져도
/// 잃을 것이 없다 — 속도를 뚜렷하게 늦춘다.
@MainActor
enum Voice {
    private static let synth = AVSpeechSynthesizer()
    private static var sessionReady = false

    /// 소리 낼 자리를 미리 잡아 둔다.
    ///
    /// **말하는 순간에 잡으면 앞머리가 먹힌다.** 세션이 올라오는 짧은 사이에 이미 말이
    /// 시작되는데, 0.2초짜리 소리에서는 그 사이에 거의 다 지나가 버린다.
    ///
    /// `.mixWithOthers` 인 것은 **애니를 보면서 쓰는 앱**이기 때문이다. 소리를
    /// 들으려고 눌렀는데 보던 영상이 멈추면, 얻은 것보다 잃은 것이 크다.
    private static func prepareSession() {
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

    static func speak(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        prepareSession()
        synth.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = japanese
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.4
        // 앞의 말을 끊고 바로 이어 말하면 첫 소리가 잘린다. 짧은 사이를 두어
        // 세션과 합성기가 준비된 뒤에 말이 시작되게 한다.
        utterance.preUtteranceDelay = 0.08
        synth.speak(utterance)
    }
}

/// 소리 단추. 가나가 놓인 자리 곁에 선다.
///
/// **아이콘 하나로만 둔다.** "듣기" 같은 글자를 붙이면 화면마다 자리를 더 먹는데,
/// 소리를 뜻하는 그림은 이미 모두가 안다.
///
/// **목록의 줄에는 붙이지 않는다.** 줄을 누르면 상세가 열리는 자리라, 그 안에 또
/// 누를 것이 있으면 어디를 눌러야 할지 매번 겨누게 된다. 소리는 펼친 자리에서 듣는다.
struct SpeakButton: View {
    let text: String
    var size: CGFloat = 15

    var body: some View {
        Button { Voice.speak(text) } label: {
            Image(systemName: "speaker.wave.2")
                .font(.system(size: size))
                .foregroundStyle(Theme.grey2)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("소리 듣기")
    }
}
