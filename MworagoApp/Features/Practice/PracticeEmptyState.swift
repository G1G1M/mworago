import SwiftUI

/// 연습할 것이 없을 때. 화면 한가운데 서고 글줄은 왼쪽에서 시작한다 —
/// 책장의 빈 화면과 같은 꼴이라 탭을 옮겨도 같은 말을 같은 자리에서 만난다.
///
/// 좌우 여백을 폭 **안쪽**에 둔다. 폭을 잰 뒤에 붙이면 덩어리가
/// `readWidth + 여백` 이 되어 재 둔 폭이 실제와 어긋난다.
struct PracticeEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("연습할 것이 없어요")
                .font(Theme.korean(.heading, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("모은 낱말을 가나만 보고 떠올려 보는 자리예요.")
                .font(Theme.korean(.body))
                .foregroundStyle(Theme.grey2)
            Text("찾기에서 낱말 옆의 갈피표를 누르면 여기로 와요.")
                .font(Theme.korean(.sub))
                .foregroundStyle(Theme.grey3)
        }
        .padding(.horizontal, Theme.gutter)
        .frame(maxWidth: Theme.readWidth, alignment: .leading)
        // 글은 왼쪽에서 시작하되 **덩어리는 화면 가운데 선다.** 아이패드처럼 넓은 화면에서
        // 폭만 묶어 두면 덩어리가 왼쪽에 붙어, 오른쪽이 통째로 비어 보인다.
        .frame(maxWidth: .infinity)
        // 첫 줄을 책장의 빈 화면과 같은 높이에 세운다 — 자세한 까닭은 `emptyBlockHeight`.
        .frame(minHeight: Theme.emptyBlockHeight, alignment: .topLeading)
        // `ZStack` 안이라 이것 없이도 가운데로 오지만, 책장의 빈 화면과 **같은 문법**으로
        // 세워 둔다. 기준이 다르면 한쪽만 손댔을 때 두 화면이 소리 없이 어긋난다.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
