import SwiftUI

/// 지울 수 있는 줄. 편집 중일 때만 단추가 앞에 선다.
struct DeletableRow<Content: View>: View {
    /// 지우는 손이 얹혔는가. 책장 머리의 `지우기` · `완료` 가 켜고 끈다.
    let editing: Bool
    let onRemove: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 0) {
            if editing {
                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 21))
                        .foregroundStyle(Theme.destructive)
                        .padding(.leading, Theme.gutter)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("지우기")
            }
            content()
        }
    }
}
