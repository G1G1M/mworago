import SwiftUI

/// 연습할 것이 없을 때. 화면 한가운데 서고 글줄은 왼쪽에서 시작한다 —
/// 책장의 빈 화면과 같은 꼴이라(`emptyBlockFrame`) 탭을 옮겨도 같은 말을 같은 자리에서 만난다.
struct PracticeEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("연습할 것이 없어요")
                .font(Theme.korean(.heading, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("모은 낱말을 가나만 보고 떠올려 보는 자리예요.")
                .font(Theme.korean(.body))
                .foregroundStyle(Theme.grey2)
            Text.bookmarkGuide("찾기에서 낱말 옆의 갈피표를 누르면 여기로 와요.")
                .font(Theme.korean(.sub))
                .foregroundStyle(Theme.grey3)
        }
        .emptyBlockFrame()
    }
}
