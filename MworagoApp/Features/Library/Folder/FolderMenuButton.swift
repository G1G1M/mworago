import SwiftUI

/// 이 묶음에 할 수 있는 일을 여는 단추.
///
/// **동그랗다.** 납작한 캡슐은 글자를 담으려고 옆으로 늘인 꼴인데 여기 담긴 것은
/// 점 세 개뿐이라, 가로로 늘이면 빈 자리만 넓어진다. 기호 하나에는 원이 맞다.
/// 줄임표는 애플이 이 자리에 쓰는 기호다(메모·파일이 그렇다) — 이름 옆에 서므로
/// 글자보다 기호가 낫다. 이름과 겨루지 않는다.
///
/// 무엇을 할 수 있는지만 이 단추가 안다. 그 일을 실제로 하는 것(판을 띄우고 고르기를
/// 켜는 것)은 묶음 화면이 한다 — 판과 알림이 그 화면 위에 떠야 하기 때문이다.
struct FolderMenuButton: View {
    /// 목록이 펼쳐져 있는가. `--menu` 로 펼친 채 띄울 수 있어 묶음 화면이 쥔다.
    @Binding var isOpen: Bool
    /// 고르는 중인가. 그동안은 단추가 켜진 채로 서고, 목록의 줄이 `고르기 마치기` 로 바뀐다.
    let selecting: Bool
    /// 담긴 것이 있는가. 없으면 연습할 것도 고를 것도 없다.
    let hasWords: Bool
    /// 사용자가 이름 지은 묶음인가. 이름을 바꾸거나 없애는 일은 그런 묶음에만 있다.
    let isNamed: Bool
    let onPractice: () -> Void
    let onToggleSelecting: () -> Void
    let onRename: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Button { isOpen = true } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .medium))
                .frame(width: 38, height: 38)
                .background(isOpen || selecting ? Theme.ink : Theme.grey4, in: Circle())
                .foregroundStyle(isOpen || selecting ? Theme.paper : Theme.grey1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("이 묶음 손보기")
        // **목록도 앱의 얼굴로 짓는다.** 시스템 메뉴는 글자체부터 남의 것이라
        // 그 순간만 다른 앱이 된다. 뜨는 자리(단추 옆)는 시스템에 맡기고
        // 안에 서는 것만 이쪽에서 그린다.
        .popover(isPresented: $isOpen, arrowEdge: .top) {
            menuList
                .presentationCompactAdaptation(.popover)
                .presentationBackground(Theme.paper)
        }
    }

    /// 할 수 있는 일들. 자주 하는 것이 위, 되돌릴 수 없는 것이 맨 아래다.
    private var menuList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if hasWords {
                menuRow("이 묶음 연습", symbol: "rectangle.stack", action: onPractice)
                menuDivider
                // 켜는 자리와 끄는 자리를 같게 둔다. 밖에 따로 세우지 않으므로
                // 여기서 켜고 여기서 끈다.
                menuRow(selecting ? "고르기 마치기" : "낱말 고르기",
                        symbol: selecting ? "checkmark" : "checkmark.circle",
                        action: onToggleSelecting)
            }
            if isNamed {
                if hasWords { menuDivider }
                menuRow("이름 바꾸기", symbol: "pencil", action: onRename)
                menuDivider
                menuRow("묶음 없애기", symbol: "trash", destructive: true, action: onRemove)
            }
        }
        .frame(width: 208)
    }

    private var menuDivider: some View {
        Theme.rule(Theme.grey4).padding(.horizontal, 16)
    }

    /// 목록 한 줄. 글이 왼쪽, 기호가 오른쪽 — 애플의 메뉴와 차례가 같다.
    private func menuRow(_ title: String, symbol: String, destructive: Bool = false,
                         action: @escaping () -> Void) -> some View {
        Button {
            // **누른 뒤에 목록이 닫힌다.** 열어 둔 채로 다음 화면을 띄우면
            // 판과 목록이 함께 떠 있는 순간이 생긴다.
            isOpen = false
            action()
        } label: {
            HStack(spacing: 12) {
                Text(title)
                    .font(Theme.korean(.body))
                Spacer(minLength: 8)
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(destructive ? Color.red : Theme.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
