import SwiftUI
import MworagoCore

/// 묶음 한 줄 — 묶음이든 날짜든 같은 꼴이다. 눈이 두 번 배우지 않아도 된다.
///
/// **한 줄 안에서 끝난다.** 이름과 개수만 두면 스무 편도 한 화면에 들어오지만
/// 이름만으로는 "어느 화였지"가 안 떠오른다. 그래서 오른쪽에 **낱말 두 개를 회색으로
/// 흘려** 둔다 — 읽으라고 두는 것이 아니라 어느 무리인지 짚어 주는 단서다.
///
/// 누르면 건네받은 `route` 로 들어간다. 무엇으로 들어갈지(묶음 · 날짜)는 책장이 정한다.
struct LibraryGroupRow<Route: Hashable>: View {
    let name: String
    /// 이름 없는 무리(아직 안 넣은 것)는 한 단 흐리게 둔다.
    let dim: Bool
    let words: [CollectedWord]
    let route: Route

    var body: some View {
        NavigationLink(value: route) {
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text(name)
                    .font(Theme.korean(.title, weight: .medium))
                    .foregroundStyle(dim ? Theme.grey2 : Theme.ink)
                Text("\(words.count)")
                    .font(Theme.korean(.sub))
                    .foregroundStyle(Theme.grey3)

                Spacer(minLength: 12)

                // 담긴 것이 없으면 흘릴 낱말도 없다. 그 자리를 비워 두면 줄이 반쯤
                // 지워진 것처럼 보이므로, 비었다고 적는다.
                if words.isEmpty {
                    Text("비어 있음")
                        .font(Theme.korean(.sub))
                        .foregroundStyle(Theme.grey3)
                } else {
                    Text(words.prefix(2).map(\.reading).joined(separator: " · "))
                        .font(Theme.japanese(.sub))
                        .foregroundStyle(Theme.grey3)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                RowChevron()
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 17)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("이 묶음을 엽니다")
    }
}
