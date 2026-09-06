import SwiftUI

/// 좌우로 밀어 이웃한 것으로 넘어가는 자리.
///
/// 펼쳐 본 낱말·글자는 **목록 안의 한 자리**다. 하나를 열어 보고 다음 것을 보려면
/// 닫고 → 목록에서 찾고 → 다시 열어야 했는데, 열 개를 훑으면 그 왕복이 열 번이다.
/// 목록으로 돌아가는 일은 자리를 옮기는 일이지만, 옆 낱말로 가는 일은 그렇지 않다.
///
/// **넘기는 일은 시스템에 맡긴다.** 온보딩에 적어 둔 것과 같은 까닭이다 —
/// 직접 만들면 속도·되돌아옴·경계에서 멈추는 것까지 다시 만들어야 하고,
/// 그렇게 만든 것은 시스템이 주는 손맛과 미묘하게 어긋난다.
///
/// **`TabView` 가 아니라 스크롤이다.** 탭바를 품은 `TabView` 는 아이패드에서 제 자리를
/// 스스로 정하려 들어 화면이 두 벌 그려진 적이 있다(`MworagoApp.swift`). 여기서 필요한
/// 것은 페이지 단위로 멎는 가로 스크롤뿐이므로 그것만 쓴다.
struct Pager<Item: Identifiable, Content: View>: View {
    let items: [Item]
    /// 지금 보고 있는 것. 넘기면 이 값이 따라 바뀐다.
    @Binding var current: Item.ID?
    /// 손으로 미는 것을 막는다. **가로 축의 뜻이 한 화면에 둘일 수는 없다** —
    /// 바깥에서 이미 가로로 미는 일(화면 넘기기)을 맡고 있으면, 안쪽은 자리를 내주고
    /// 단추로만 넘어간다. 자리를 옮기는 것(`current` 를 바꾸는 것)은 그대로 미끄러진다.
    var scrollDisabled = false
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(items) { item in
                    content(item)
                        // 한 장이 화면 폭을 그대로 쓴다. 옆 장이 비죽 보이면 카드 더미가
                        // 되는데, 여기 있는 것은 더미가 아니라 **한 번에 하나**다.
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        // 한 장뿐이면 튀지 않는다. 넘길 곳이 없는데 손을 대면 밀리는 것은,
        // 더 있다고 말해 놓고 없는 것과 같다.
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .scrollPosition(id: $current)
        .scrollDisabled(scrollDisabled)
    }
}

/// 몇 번째를 보고 있는지. 내비 바 가운데에 선다.
///
/// **넘길 수 있다는 것을 이것이 말한다.** 한 장이 폭을 다 쓰므로 옆 장이 보이지 않고,
/// 그러면 밀어 볼 생각을 할 단서가 화면에 없다. 자리를 알려 주는 일과 겸한다.
///
/// 하나뿐이면 아무것도 그리지 않는다 — `1 / 1` 은 셀 것이 없다는 말을 굳이 하는 것이다.
struct PagerPosition: View {
    let index: Int?
    let total: Int

    var body: some View {
        if let index, total > 1 {
            Text("\(index + 1) / \(total)")
                .font(Theme.korean(.sub))
                .foregroundStyle(Theme.grey2)
                .monospacedDigit()
                .accessibilityLabel("\(total)개 중 \(index + 1)번째")
        }
    }
}
