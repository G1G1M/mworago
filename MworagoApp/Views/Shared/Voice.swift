import SwiftUI
import MworagoCore

/// 소리 단추. 가나가 놓인 자리 곁에 선다.
///
/// **아이콘 하나로만 둔다.** "듣기" 같은 글자를 붙이면 화면마다 자리를 더 먹는데,
/// 소리를 뜻하는 그림은 이미 모두가 안다.
///
/// **목록의 줄에는 붙이지 않는다.** 줄을 누르면 상세가 열리는 자리라, 그 안에 또
/// 누를 것이 있으면 어디를 눌러야 할지 매번 겨누게 된다. 소리는 펼친 자리에서 듣는다.
///
/// **소리 내는 일은 환경에서 받는다**(`\.speaker`). 예전에는 합성기를 들고 있는
/// 전역 enum 을 곧바로 불렀고, 그래서 소리를 내지 않고 화면을 확인할 길이 없었다.
struct SpeakButton: View {
    let text: String
    var size: CGFloat = 15
    /// 기본은 낱말이다. 이 단추가 서는 자리는 대개 낱말 곁이고, 문장은 한 곳뿐이다.
    var pace: SpeechPace = .word

    @Environment(\.speaker) private var speaker

    var body: some View {
        Button { speaker.speak(text, pace: pace) } label: {
            Image(systemName: "speaker.wave.2")
                .font(.system(size: size))
                .foregroundStyle(Theme.grey2)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("소리 듣기")
    }
}
