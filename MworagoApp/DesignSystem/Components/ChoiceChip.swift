import SwiftUI

/// 여럿 중 하나를 고르는 알약 — 고른 것 하나만 검게 채워진다.
///
/// **네 자리가 같은 알약을 각자 그리고 있었다** — 책장의 보기 전환, 글자 표의
/// 히라가나 · 가타카나, 익히기의 범위와 순서. 유리는 씌우지 않는다. 그것은 **떠 있는**
/// 컨트롤의 표시인데 이쪽은 글에 붙어 있다.
///
/// 무엇이 골라졌는지와 누르면 무엇을 할지는 부르는 쪽이 정한다 — 보기를 바꾸며
/// 애니메이션을 걸지, 덱을 새로 섞을지는 자리마다 다르다.
struct ChoiceChip: View {
    let title: String
    let isSelected: Bool
    /// `.sub` 가 기본, 곁에 딸린 작은 다이얼은 `.tag` 다. 크기에 따라 여백도 함께 준다.
    var size: Theme.Size = .sub
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.korean(size, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, size == .tag ? 9 : 12)
                .padding(.vertical, size == .tag ? 5 : 7)
                .background(isSelected ? Theme.ink : .clear, in: Capsule())
                .foregroundStyle(isSelected ? Theme.paper : Theme.grey2)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
