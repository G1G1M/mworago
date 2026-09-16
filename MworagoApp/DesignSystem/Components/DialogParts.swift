import SwiftUI

// 가운데 판(`dialog`) 안에 서는 조각들.
//
// **판 넷이 같은 머리 · 같은 줄 · 같은 단추를 각자 그리고 있었다** — 담기 · 옮기기 ·
// 이름 짓기 · 연습 고르기. 한 곳에서 여백을 1pt 고치면 나머지 셋과 어긋나므로
// 모양은 여기 한 벌만 둔다. 판마다 다른 것(무엇을 고르는지, 저장이 할 일이 있는지)은
// 부르는 쪽에 남는다.

/// 판의 머리 — 무엇을 묻는지 한 줄, 그 아래 무엇이 달라지는지 한 줄.
struct DialogHead: View {
    let title: String
    let hint: String
    /// 머리와 첫 줄 사이. 줄이 바로 붙는 판은 12, 입력 칸이 붙는 판은 14 다.
    var bottom: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(Theme.korean(.title))
                .foregroundStyle(Theme.ink)
            Text(hint)
                .font(Theme.korean(.sub))
                .foregroundStyle(Theme.grey2)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, bottom)
    }
}

/// 판 아래의 알약 단추. 채운 것이 하려는 일, 흐린 것이 물러나는 일이다.
struct DialogButton: View {
    let title: String
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.korean(.body))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(prominent ? Theme.ink : Theme.grey4, in: Capsule())
                .foregroundStyle(prominent ? Theme.paper : Theme.grey1)
        }
        .buttonStyle(.plain)
    }
}

/// 하려는 일과 그만두기, 두 단추를 나란히 세운다.
///
/// 할 일이 없으면 **막고 흐리게** 둔다. 눌러도 아무 일이 없는 단추보다
/// "무엇이 달라지는가"를 단추가 대신 말해 주는 편이 낫다.
struct DialogActions: View {
    let confirmTitle: String
    var canConfirm = true
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            DialogButton(title: confirmTitle, prominent: true, action: onConfirm)
                .disabled(!canConfirm)
                .opacity(canConfirm ? 1 : 0.4)
            DialogButton(title: "그만두기", action: onCancel)
        }
        .padding(.horizontal, 20)
    }
}

/// 판 안에서 무리를 가르는 옅은 선.
struct DialogDivider: View {
    var body: some View {
        Theme.rule(Theme.grey4)
            .padding(.horizontal, 20)
            .padding(.vertical, 5)
    }
}

/// 하나를 고르는 줄. 왼쪽 점이 **지금 고른 것**을 가리키고, 오른쪽 자리는 판마다 다르다 —
/// 원래 있던 자리(`지금`), 지난번 넣은 곳, 몇 개인지.
struct RadioRow<Trailing: View>: View {
    let title: String
    let isPicked: Bool
    /// 묶음이 아닌 자리(나중에 정하기 · 아직 안 넣은 것)는 한 단 흐리게 둔다.
    var dim = false
    /// 긴 이름을 한 줄로 자를 것인가. 담기 판은 자르지 않는다.
    var singleLine = true
    let action: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Circle()
                    .strokeBorder(isPicked ? Theme.ink : Theme.grey3, lineWidth: 1.5)
                    .background(Circle().fill(isPicked ? Theme.ink : .clear).padding(3.5))
                    .frame(width: 16, height: 16)
                Text(title)
                    .font(Theme.korean(.body))
                    .foregroundStyle(dim ? Theme.grey1 : Theme.ink)
                    .lineLimit(singleLine ? 1 : nil)
                Spacer(minLength: 10)
                trailing()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isPicked ? [.isSelected] : [])
    }
}
