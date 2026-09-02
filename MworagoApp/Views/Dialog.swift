import SwiftUI

/// 화면 한가운데 서는 작은 판.
///
/// **시트가 아니다.** 시트는 아래에서 올라와 화면을 넘겨받는 몸짓이라 "다음 화면"으로
/// 읽힌다. 이름 한 줄을 받거나 무엇을 할지 고르는 일은 화면을 옮기는 일이 아니라
/// **지금 화면에 무언가를 묻는 일**이고, 그것은 알림의 몸짓이다 — 바탕이 어두워지고
/// 가운데에 판이 떠오른다.
///
/// 시스템 알림을 쓰지 않는 것은 **그 판만 남의 앱 얼굴이기 때문**이다.
/// 글자가 고운돋움이 아니고, 파란 글씨 단추는 이 앱 어디에도 없다.
struct Dialog<Body: View>: ViewModifier {
    @Binding var isPresented: Bool
    @ViewBuilder var dialogBody: () -> Body

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    ZStack {
                        // 바탕을 눌러도 닫힌다. 알림의 규칙은 아니지만, 이 판이 묻는 것은
                        // 되돌릴 수 없는 일이 아니라 **하다 말 수 있는 일**이다.
                        Theme.ink.opacity(0.22)
                            .ignoresSafeArea()
                            .onTapGesture { close() }
                            .transition(.opacity)

                        dialogBody()
                            .frame(width: 320)
                            .background(Theme.paper,
                                        in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            // 판이 바탕에서 떠 있다는 것은 그림자가 말한다. 이 앱에서
                            // 그림자를 쓰는 자리는 여기뿐이라, 떠 있는 것이 하나임이 보인다.
                            .shadow(color: Theme.ink.opacity(0.18), radius: 26, y: 10)
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
            }
            .animation(.snappy(duration: 0.18), value: isPresented)
    }

    private func close() { isPresented = false }
}

extension View {
    /// 알림 판을 띄운다. 안에 무엇을 넣을지는 부르는 쪽이 정한다 —
    /// 이름을 받는 자리와 할 일을 고르는 자리가 같은 판을 쓴다.
    func dialog<Body: View>(isPresented: Binding<Bool>,
                            @ViewBuilder content: @escaping () -> Body) -> some View {
        modifier(Dialog(isPresented: isPresented, dialogBody: content))
    }
}
