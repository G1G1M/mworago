import SwiftUI

/// 줄 끝의 `›` — 누르면 다음 화면으로 간다는 표시.
///
/// 책장의 묶음 줄 · 설정 줄 · 의견 보내기가 같이 쓴다. 같은 기호가 같은 일을 하는데
/// 화면마다 1pt 씩 다르면, 탭을 옮길 때 줄 끝만 흔들린다.
struct RowChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(Theme.icon(.chevron, weight: .medium))
            .foregroundStyle(Theme.grey3)
    }
}

extension View {
    /// 시트 오른쪽 위의 `닫기`. 펼쳐 보는 화면 셋(낱말 · 글자 · 치는 법)이 같이 쓴다.
    func closeToolbar(_ close: @escaping () -> Void) -> some View {
        toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("닫기", action: close)
                    .font(Theme.korean(.body))
                    .foregroundStyle(Theme.ink)
            }
        }
    }
}
