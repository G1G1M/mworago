import SwiftUI

/// 떠 있는 컨트롤의 바탕 — 판 하나에 유리를 입힌다.
///
/// **iOS 26 에서는 리퀴드 글래스를 쓴다.** 탭바가 이미 그 유리라, 바로 위에 뜬 입력 바만
/// 흐린 재질이면 떠 있는 것 둘이 다른 물건으로 보인다. 유리는 가장자리 빛을 스스로
/// 그리므로 덧그리던 회색 실선은 두지 않는다.
///
/// **그 아래에서는 예전 바탕을 그대로 쓴다** — 흐린 재질과 회색 실선 0.5.
/// 앱은 iOS 18 부터 돌므로 한쪽만 남길 수 없다.
///
/// 입력 바와 스플래시가 **같은 것을 입는다.** 스플래시의 알약이 마지막에 입력 바가 되는데,
/// 둘의 바탕이 다르면 걷히는 순간 재질이 한 번 바뀌어 보인다. 바로 위에 뜨는 담은 자리
/// 알림도 같은 유리다 — 답 목록이 둘 밑으로 함께 흘러가므로 하나만 불투명하면 튄다.
struct GlassSurface<S: InsettableShape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(Theme.grey3.opacity(0.5), lineWidth: 0.5))
        }
    }
}

extension View {
    func glassSurface(cornerRadius: CGFloat) -> some View {
        modifier(GlassSurface(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)))
    }

    /// 알약 꼴. 입력 바 위에 뜨는 짧은 줄(담은 자리 알림)이 입는다.
    func glassCapsule() -> some View {
        modifier(GlassSurface(shape: Capsule()))
    }
}
