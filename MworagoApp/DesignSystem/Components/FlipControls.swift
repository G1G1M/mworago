import SwiftUI

/// 뒤집는 카드 아래의 세 단추 — `이전` · `뒤집기` · `다음`.
///
/// 낱말 연습과 가나 익히기가 **같은 몸짓**을 쓴다. 두 화면이 하는 일이 같으므로
/// 단추의 차례 · 채우는 자리 · 뒤집는 결이 같아야 한다. 크기만 다르다 —
/// 익히기는 화면에 글자 하나뿐이라 단추도 한 단 크다.
///
/// **검게 채우는 것은 가운데 하나뿐이다.** 이 화면에서 하는 일은 뒤집는
/// 것이고, `이전`·`다음` 은 그 일을 하고 나서 자리를 옮기는 것이다.
/// 셋 중 둘이 번갈아 검어지면 무엇이 지금 할 일인지가 흐려진다.
struct FlipControls: View {
    enum Size {
        /// 낱말 연습. 카드 아래 글이 여러 줄이라 단추가 앞에 나서지 않는다.
        case regular
        /// 가나 익히기. 화면에 글자 하나뿐이다.
        case large
    }

    @Binding var revealed: Bool
    var size: Size = .regular
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: size == .large ? 12 : 10) {
            // 되돌아갈 길. 지나친 것을 다시 보려고 한 바퀴를 돌 이유가 없다.
            button("이전", filled: false, action: onPrevious)
            button(revealed ? "다시 덮기" : "뒤집기", filled: true) {
                withAnimation(Flip.motion) { revealed.toggle() }
            }
            button("다음", filled: false, action: onNext)
        }
    }

    private func button(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.korean(size == .large ? .title : .body))
        }
        .matteButton(prominent: filled)
        .controlSize(size == .large ? .extraLarge : .large)
    }
}
