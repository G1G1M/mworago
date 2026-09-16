import SwiftUI

/// 이 묶음에 할 수 있는 일을 여는 단추.
///
/// **동그랗다.** 납작한 캡슐은 글자를 담으려고 옆으로 늘인 꼴인데 여기 담긴 것은
/// 점 세 개뿐이라, 가로로 늘이면 빈 자리만 넓어진다. 기호 하나에는 원이 맞다.
/// 줄임표는 애플이 이 자리에 쓰는 기호다(메모·파일이 그렇다) — 이름 옆에 서므로
/// 글자보다 기호가 낫다. 이름과 겨루지 않는다.
///
/// 단추는 열기만 한다. 목록(`FolderMenuList`)과 그 일을 실제로 하는 것(판을 띄우고
/// 고르기를 켜는 것)은 묶음 화면이 쥔다 — 목록 · 판 · 알림이 그 화면 위에 떠야 하기 때문이다.
struct FolderMenuButton: View {
    /// 목록이 펼쳐져 있는가. `--menu` 로 펼친 채 띄울 수 있어 묶음 화면이 쥔다.
    @Binding var isOpen: Bool

    var body: some View {
        Button { isOpen = true } label: {
            // **열어도 색이 바뀌지 않는다.** 한때 목록이 펼쳐지면 검게 채웠는데, 이 앱에서
            // 검게 채워지는 것은 "지금 고른 것"이라 단추가 켜진 상태로 읽혔다. 열린 것은
            // 바로 밑에 뜬 목록이 이미 말한다.
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .medium))
                .frame(width: 38, height: 38)
                .background(Theme.grey4, in: Circle())
                .foregroundStyle(Theme.grey1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("이 묶음 손보기")
        // 목록이 단추 밑에 뜨도록 제 자리를 묶음 화면에 올린다.
        .anchorPreference(key: FolderMenuAnchor.self, value: .bounds) { $0 }
    }
}

/// 줄임표 단추가 놓인 자리. 묶음 화면이 받아 그 밑에 목록을 띄운다.
struct FolderMenuAnchor: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

/// 이 묶음에 할 수 있는 일들. 줄임표 단추 밑에 뜬다.
///
/// **시스템 팝오버를 쓰지 않고 화면 안에 띄운다.** 팝오버는 따로 떠 있는 층이라, 그 위에
/// 입힌 유리는 뒤의 목록을 비출 수 없다 — 시스템이 그리는 유리에 기대야 하는데,
/// iOS 26.3 에서는 옅게 비치던 그 바탕이 iOS 27 에서는 불투명한 흰 판으로 그려졌다.
/// 입력 바 · 탭바와 같은 층에 뜬 것이 혼자 막힌 판이 된다. 화면 안에 두면 입력 바와
/// 같은 유리가 뒤의 목록을 그대로 비춘다.
///
/// 글자체도 앱의 것이다. 시스템 메뉴는 글자체부터 남의 것이라 그 순간만 다른 앱이 된다.
struct FolderMenuList: View {
    /// 고르는 중이면 `낱말 고르기` 가 `고르기 마치기` 로 바뀐다.
    let selecting: Bool
    /// 담긴 것이 있는가. 없으면 연습할 것도 고를 것도 없다.
    let hasWords: Bool
    /// 사용자가 이름 지은 묶음인가. 이름을 바꾸거나 없애는 일은 그런 묶음에만 있다.
    let isNamed: Bool
    /// 목록을 닫는다. 줄을 누르면 일을 하기 전에 먼저 닫는다.
    let onClose: () -> Void
    let onPractice: () -> Void
    let onToggleSelecting: () -> Void
    let onRename: () -> Void
    let onRemove: () -> Void

    /// 목록의 폭. 묶음 화면이 단추 오른쪽 끝에 맞춰 놓을 때도 쓴다.
    static let width: CGFloat = 208

    /// 할 수 있는 일들. 자주 하는 것이 위, 되돌릴 수 없는 것이 맨 아래다.
    var body: some View {
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
        .padding(.vertical, 4)
        .frame(width: Self.width)
        // **옅은 유리다.** 기본 유리는 이 크기에서 뒤를 거의 가려 흰 판으로 보였고,
        // 맑은 유리는 뒤의 낱말이 메뉴 글자와 겹쳐 읽혔다.
        .glassSurface(cornerRadius: 20, sheer: true)
        // 떠 있는 동안에는 이 목록만 읽힌다. 시스템 팝오버가 해 주던 일을 대신 한다.
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onClose)
    }

    private var menuDivider: some View {
        Theme.rule(Theme.grey3.opacity(0.5)).padding(.horizontal, 16)
    }

    /// 목록 한 줄. 글이 왼쪽, 기호가 오른쪽 — 애플의 메뉴와 차례가 같다.
    private func menuRow(_ title: String, symbol: String, destructive: Bool = false,
                         action: @escaping () -> Void) -> some View {
        Button {
            // **누른 뒤에 목록이 닫힌다.** 열어 둔 채로 다음 화면을 띄우면
            // 판과 목록이 함께 떠 있는 순간이 생긴다.
            onClose()
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
