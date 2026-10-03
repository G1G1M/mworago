import SwiftUI

/// 묶음을 만드는 줄. 묶음들이 선 목록의 맨 끝에 이어 붙는다.
///
/// **담기 모달에도 만드는 길이 있지만 하는 일이 다르다.** 그쪽은 낱말을 손에 들고
/// 만드는 것이라 만들면 곧 담긴다. 여기서 만드는 것은 **비어 있는 자리**다 —
/// 다음 화를 보기 전에 이름을 세워 두고, 담을 때 그 자리를 고른다.
struct NewFolderRow: View {
    /// 이름을 받는 판을 띄운다. 판은 책장이 쥔다.
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: "plus")
                    .font(Theme.icon(.action, weight: .medium))
                    .frame(width: 16)
                Text("새 묶음 만들기")
                    .font(Theme.korean(.body))
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.grey1)
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 17)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("담긴 것이 없는 묶음을 미리 만듭니다")
    }
}
