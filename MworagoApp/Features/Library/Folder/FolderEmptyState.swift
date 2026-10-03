import SwiftUI

/// 담긴 것이 없을 때. **자리는 있고 아직 아무것도 넣지 않았을 뿐이다** —
/// 그렇게 보이게 적는다. 잘못 들어온 화면이 아니라는 것이 먼저다.
///
/// 책장의 빈 화면처럼 가운데 세우지 않는다. 여기는 이름이 위에 서 있는 화면이라,
/// 글이 이름 아래에서 이어져야 그 묶음에 대한 말로 읽힌다.
struct FolderEmptyState: View {
    /// 사용자가 이름 지은 묶음인가. 아니면 "아직 안 넣은 것"이다.
    let isNamed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(isNamed ? "이 묶음은 아직 비어 있어요" : "아직 담은 것이 없어요")
                .font(Theme.korean(.title, weight: .medium))
                .foregroundStyle(Theme.grey1)
            Text(isNamed
                 ? "찾기에서 낱말 옆의 갈피표를 누르고 이 묶음을 고르면 여기 모여요."
                 : "찾기에서 낱말 옆의 갈피표를 누르면 여기 모여요.")
                .font(Theme.korean(.body))
                .foregroundStyle(Theme.grey2)
        }
        .padding(.horizontal, Theme.gutter)
    }
}
