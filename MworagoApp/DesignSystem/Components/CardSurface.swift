import SwiftUI

/// 뒤집는 카드의 바탕 — 종이색 판 · 머리카락 테두리 · 아주 옅은 그림자.
///
/// 낱말 연습과 가나 익히기가 **같은 카드**를 쓴다. 한쪽만 모서리나 그림자를 고치면
/// 탭을 옮길 때 카드가 다른 물건으로 보인다. 안쪽 여백은 담기는 것이 달라 부르는 쪽에 둔다.
struct CardSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.grey3.opacity(0.45), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 10, y: 3)
    }
}

extension View {
    func cardSurface() -> some View { modifier(CardSurface()) }
}
