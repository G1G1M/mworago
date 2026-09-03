import SwiftUI
import UIKit

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
                    DialogCard(close: { isPresented = false }, content: dialogBody)
                }
            }
            .animation(.dialog, value: isPresented)
    }
}

extension Animation {
    /// 판이 뜨고 지는 결.
    ///
    /// **`.snappy(duration: 0.18)` 이었다.** `.snappy` 는 튀는 성질(bounce 0.15)이 있는
    /// 용수철이고 0.18초는 그 튐이 한 번에 끝나는 길이라, 판이 떠오르는 것이 아니라
    /// **한 번 깜빡이는 것**처럼 보였다. 바탕이 어두워지는 것까지 같은 길이로 끝나
    /// 화면 전체가 한 프레임 만에 뒤집혔다.
    ///
    /// `.smooth` 는 튐이 없는 용수철이다. 0.3초는 이 앱이 화면을 넘길 때 쓰는
    /// 0.18~0.22초보다 한 뼘 길지만, 판은 화면을 넘기는 것이 아니라 **위에 떠오르는**
    /// 것이라 조금 느긋한 편이 몸짓에 맞는다.
    static let dialog = Animation.smooth(duration: 0.3)
}

/// 무엇을 두고 묻는 판. 물을 것이 정해지면(갈피표를 누른 낱말) 그것과 함께 뜬다.
struct ItemDialog<Item: Identifiable, Body: View>: ViewModifier {
    @Binding var item: Item?
    @ViewBuilder var dialogBody: (Item) -> Body

    func body(content: Content) -> some View {
        content
            .overlay {
                if let item {
                    DialogCard(close: { self.item = nil }) { dialogBody(item) }
                }
            }
            .animation(.dialog, value: item != nil)
    }
}

/// 판의 몸. 폭·바닥·그림자를 한 자리에서 정한다 — 이름을 받는 판과 고르는 판이
/// 다른 크기로 뜨면 같은 자리에서 나온 것으로 보이지 않는다.
private struct DialogCard<Body: View>: View {
    let close: () -> Void
    @ViewBuilder var content: () -> Body

    /// 바탕을 눌러 닫을 때도 **키보드를 먼저 내려보낸다.**
    ///
    /// 판 안에 글 칸이 있으면(`FolderNameDialog`) 그것을 든 채로 판을 지우는 순간
    /// 키보드가 미끄러지지 않고 툭 꺼진다. 닫는 길은 단추 · 바깥 탭으로 여럿이라
    /// **길마다 같은 규칙을 건다** — 한 길만 고치면 나머지 길에서 그대로 남는다.
    /// 여기서는 판 안의 `@FocusState` 에 닿을 수 없으므로 지금 초점을 든 것에게 직접 묻는다.
    private func dismiss() {
        // **키보드가 있었을 때만 기다린다.** `sendAction` 은 받을 것이 있었는지를
        // 돌려준다 — 글 칸이 없는 판(담기 · 옮기기)까지 한 박자 늦추면
        // 부드러워지는 것이 아니라 그냥 굼뜬 것이 된다.
        let hadKeyboard = UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        guard hadKeyboard else { return close() }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(90))
            close()
        }
    }

    var body: some View {
        ZStack {
            // 바탕을 눌러도 닫힌다. 알림의 규칙은 아니지만, 이 판이 묻는 것은
            // 되돌릴 수 없는 일이 아니라 **하다 말 수 있는 일**이다.
            Theme.ink.opacity(0.22)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)
                .transition(.opacity)

            content()
                .frame(width: 320)
                .background(Theme.paper,
                            in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                // 판이 바탕에서 떠 있다는 것은 그림자가 말한다. 이 앱에서
                // 그림자를 쓰는 자리는 여기뿐이라, 떠 있는 것이 하나임이 보인다.
                .shadow(color: Theme.ink.opacity(0.18), radius: 26, y: 10)
                // **들어올 때와 나갈 때가 다르다.** 뜰 때는 조금 더 작은 데서 자라
                // 올라와야 "떠오른" 것으로 읽히고, 닫을 때는 거의 줄지 않아야 한다 —
                // 나가면서까지 오므라들면 빨려 들어가는 것처럼 보인다.
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.94)),
                    removal: .opacity.combined(with: .scale(scale: 0.98))))
        }
    }
}

extension View {
    /// 알림 판을 띄운다. 안에 무엇을 넣을지는 부르는 쪽이 정한다 —
    /// 이름을 받는 자리와 할 일을 고르는 자리가 같은 판을 쓴다.
    func dialog<Body: View>(isPresented: Binding<Bool>,
                            @ViewBuilder content: @escaping () -> Body) -> some View {
        modifier(Dialog(isPresented: isPresented, dialogBody: content))
    }

    /// 무엇을 두고 묻는 판. 물을 것이 없으면(`nil`) 뜨지 않는다.
    func dialog<Item: Identifiable, Body: View>(item: Binding<Item?>,
                                                @ViewBuilder content: @escaping (Item) -> Body) -> some View {
        modifier(ItemDialog(item: item, dialogBody: content))
    }
}
