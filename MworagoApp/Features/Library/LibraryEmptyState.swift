import SwiftUI

/// 담긴 것이 없을 때. **연습의 빈 화면과 같은 자리에 선다** — 화면 한가운데
/// 글 덩어리 하나가 놓이고 글줄은 왼쪽에서 시작한다(`emptyBlockFrame`).
/// 빈 화면은 읽으라고 두는 것이라 목록처럼 위에서부터 채울 것이 없다.
struct LibraryEmptyState: View {
    /// 묶음을 먼저 만들어 두는 길. 이름 받는 판은 책장이 쥔다.
    let onCreateFolder: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.blockGap) {
            VStack(alignment: .leading, spacing: 12) {
                Text("아직 책장이 비어 있어요")
                    .font(Theme.korean(.heading, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text.bookmarkGuide("찾기에서 낱말 옆의 갈피표를 누르면,\n어느 묶음에 넣을지 물어보고 여기 쌓여요.")
                    .font(Theme.korean(.body))
                    .foregroundStyle(Theme.grey2)
            }
            // 온보딩 2장과 같은 이유로 낡았던 말이다. 날짜는 어느 화를 봤는지 앱이
            // 몰라서 쓰던 대용품인데, 이제 담을 때 어느 묶음에 넣을지 직접 고른다.
            Text("묶음은 마음대로 만들고, 담은 뒤에도 옮길 수 있어요.")
                .font(Theme.korean(.sub))
                .foregroundStyle(Theme.grey3)

            // **보기 전에 자리를 먼저 만들 수 있다.**
            //
            // 한때는 이 자리를 비워 두었다 — 처음 온 사람에게 할 일을 둘 내밀면
            // "찾기에서 갈피표를 누르세요"가 흐려진다는 이유였다. 그런데 다음 화를 보기
            // 전에 이름을 세워 두는 일이 이 앱의 실제 흐름이고(빈 묶음을 지원하는 까닭이
            // 그것이다), 담긴 것이 없을 때는 그 길이 아예 없었다.
            //
            // 그래서 두되 **작게** 둔다. 채우지 않은 회색 단추라 위의 글과 겨루지 않는다.
            Button(action: onCreateFolder) {
                Text("묶음 만들어 두기")
                    .font(Theme.korean(.sub))
            }
            .matteButton()
            .padding(.top, 4)
        }
        .emptyBlockFrame()
    }
}
