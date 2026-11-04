import SwiftUI

/// 찾기 빈 화면의 최근 찾은 것. 누르면 그 소리로 다시 찾는다.
///
/// **바를 눌렀을 때만 입력 바 바로 위에 선다.** 처음부터 떠 있으면 빈 화면이 어수선했다.
/// 키보드가 올라와 안내문이 물러난 자리를 이 목록이 채운다 — 칠 셈으로 바를 누른 사람에게
/// 「아까 그것」이 가장 쓸모 있는 순간이 그때다.
///
/// 무게는 낮게 둔다. 회색 글줄에 시계 그림 하나 — 안내문과 바 사이에서 앞에 나서지 않는다.
struct RecentSearchList: View {
    let queries: [String]
    let onPick: (String) -> Void
    /// 하나만 지운다. 줄 끝의 ×.
    let onRemove: (String) -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("최근 찾은 것")
                    .font(Theme.korean(.sub))
                    .foregroundStyle(Theme.grey3)
                Spacer()
                Button("지우기", action: onClear)
                    .font(Theme.korean(.sub))
                    .foregroundStyle(Theme.grey3)
                    .buttonStyle(.plain)
                    .accessibilityLabel("최근 찾은 것 지우기")
            }
            .padding(.bottom, 4)
            ForEach(queries, id: \.self) { query in
                HStack(spacing: 0) {
                    Button { onPick(query) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(Theme.icon(.control))
                                .foregroundStyle(Theme.grey3)
                            Text(query)
                                .font(Theme.korean(.body))
                                .foregroundStyle(Theme.grey1)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("이 소리로 다시 찾아요")
                    // **하나만 지우는 ×.** 「지우기」는 통째로 비우는 것뿐이라, 잘못 친 소리
                    // 하나를 치우려고 전부를 버려야 했다. 줄 끝, 손이 쉽게 닿는 자리에 둔다.
                    Button { onRemove(query) } label: {
                        Image(systemName: "xmark")
                            .font(Theme.icon(.caret, weight: .medium))
                            .foregroundStyle(Theme.grey3)
                            .touchTarget(around: Theme.IconSize.caret.rawValue)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(query) 지우기")
                }
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, 16)
    }
}
