import SwiftUI

/// 무엇을 연습하고 있는지, 그리고 바꾸는 문. **둘이 한 물건이다** — 지금 고른 것을
/// 적어 두면 그 글자가 곧 누를 자리가 된다. 고를 것이 없으면(묶음이 하나뿐이거나
/// 아예 없으면) 서지 않는다. 책장에서 하루치를 들고 왔을 때도 서지 않는다 —
/// 그때는 위의 알약이 이미 무엇을 보고 있는지 말하고 있다.
struct PracticeScopeButton: View {
    /// 지금 연습하고 있는 것의 이름. 전체면 `전체`.
    let title: String
    /// 고르는 판을 띄운다. 판은 연습 화면이 쥔다.
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                    .font(Theme.korean(.sub))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(Theme.icon(.caret, weight: .medium))
            }
        }
        .matteButton()
        .controlSize(.small)
        .accessibilityLabel("연습할 묶음 고르기")
        .accessibilityValue(title)
    }
}
