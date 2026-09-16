import SwiftUI
import MworagoCore

/// 한 장. **앞뒤가 있는 카드다.**
///
/// `뒤집기` 라고 말해 놓고 아래에 답만 나타나던 자리다. 카드를 그려 두고도 그것이
/// 돌지 않으면 그 네모는 카드가 아니라 배경이다. 앞면은 글자, 뒷면은 소리 —
/// 떠올렸다가 확인하는 이 화면의 일이 뒤집는 몸짓과 같은 모양이다.
struct KanaQuizCard: View {
    let item: KanaQuiz.Card
    /// 뒤집혔는가. 넘기면 도로 덮이는 일은 익히기 화면이 한다.
    let revealed: Bool

    @Environment(\.speaker) private var speaker

    var body: some View {
        FlipCard(angle: revealed ? 180 : 0) {
            face { front }
        } back: {
            face { back }
        }
        .frame(maxWidth: Theme.readWidth)
        .padding(.horizontal, Theme.gutter)
    }

    /// 카드의 면 하나. 연습 카드와 같은 꼴이다.
    private func face<V: View>(@ViewBuilder _ inner: () -> V) -> some View {
        inner()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 54)
            .cardSurface()
    }

    /// 앞면 — 글자 하나.
    ///
    /// 화면에 이것 하나뿐이라 본문 크기를 따를 이유가 없다. 표에서 24pt 로 훑던 글자를
    /// 여기서 크게 다시 만나는 것 자체가 "이제 이걸 본다"는 신호다.
    /// 요음은 두 자(きゃ)라 폭이 배가 되므로 줄이지 않고 넘치게 두면 안 된다.
    private var front: some View {
        Text(item.shown)
            .font(Theme.japanese(.cardFront, weight: .medium))
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .foregroundStyle(Theme.ink)
            .frame(minHeight: Self.faceHeight)
    }

    /// 뒷면 — 소리.
    ///
    /// **글자를 작게 남긴다.** 뒤집고 나서 "무엇의 답인지"를 다시 찾아 앞면으로
    /// 되돌아가게 하지 않기 위해서다.
    ///
    /// **이 줄이 곧 소리 단추다.** 스피커 모양을 그려 놓고 눌리지 않으면 그것은
    /// 그림이지 단추가 아니다. 아래에 `소리 듣기` 를 따로 두었다가 걷어낸 자리다 —
    /// 같은 일을 하는 것이 화면에 둘일 이유가 없다.
    private var back: some View {
        VStack(spacing: 22) {
            Text(item.shown)
                .font(Theme.japanese(.cardBack, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(Theme.grey2)
            Button { speaker.speak(item.kana, pace: .kana) } label: {
                HStack(spacing: 10) {
                    Image(systemName: "speaker.wave.2")
                        .font(.system(size: 20))
                    Text(KanaToHangul.transliterate(item.kana))
                        .font(Theme.korean(.display))
                }
                .foregroundStyle(Theme.ink)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("소리 듣기")
        }
        .frame(minHeight: Self.faceHeight)
    }

    /// 두 면이 함께 쓰는 최소 높이. 앞뒤가 크게 다르면 뒤집는 순간 카드가 늘었다 줄었다 한다.
    private static let faceHeight: CGFloat = 210
}
