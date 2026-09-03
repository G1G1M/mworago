import SwiftUI

/// 낱말을 고르는 중의 머리줄. 책장 `모두` 목록과 묶음 화면이 **같은 것을 쓴다.**
///
/// 한때 두 화면에 같은 코드가 두 벌 적혀 있었다. 아래의 접힘도 두 자리에서 똑같이
/// 났고, 한 자리만 고치면 다른 자리는 그대로 남는다.
///
/// **한 줄에 안 들어가면 두 줄로 선다.** 아이폰 폭에서 쓸 수 있는 자리는 354pt 인데
/// 상태 글과 단추 넷을 함께 세우면 366pt 다(단추 넷 265 · `5개 골랐어요` 92 · 사이 10 —
/// 실제로 재서 나온 값이다). 처음 상태인 `고를 낱말을 누르세요` 는 152pt 라 72pt 가
/// 모자란다. 모자란 만큼 SwiftUI 는 가장 잘 접히는 것을 접는데 그게 하필
/// **`옮기기` 알약**이었다 — 세 글자가 두 줄로 접혀 알약이 동그라미가 됐다.
///
/// 폭을 직접 재서 기기로 가르지 않고 `ViewThatFits` 에 맡긴다. 들어가면 한 줄,
/// 안 들어가면 두 줄이다 — 아이패드는 한 줄 그대로고, 글자 크기를 키운 아이폰도
/// 알아서 두 줄로 내려간다.
struct SelectionHead: View {
    let count: Int
    let allPicked: Bool
    var onToggleAll: () -> Void
    var onMove: () -> Void
    var onRemove: () -> Void
    var onDone: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 10) {
                status
                Spacer(minLength: 10)
                actions
            }
            // 두 줄일 때 단추는 **왼쪽에서 시작한다.** 이 앱의 글과 선이 다 그 자리에서
            // 시작하므로, 단추만 오른쪽 끝에 매달면 같은 화면의 것이 두 자리에서 선다.
            VStack(alignment: .leading, spacing: 10) {
                status
                HStack(spacing: 10) {
                    actions
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var status: some View {
        Text(count == 0 ? "고를 낱말을 누르세요" : "\(count)개 골랐어요")
            .font(Theme.korean(17, weight: count == 0 ? .regular : .semibold))
            .foregroundStyle(count == 0 ? Theme.grey2 : Theme.ink)
            .lineLimit(1)
    }

    @ViewBuilder
    private var actions: some View {
        headButton(allPicked ? "모두 풀기" : "모두", action: onToggleAll)
        // 고른 것이 없으면 옮길 것도 지울 것도 없다. 눌러 보고 알게 하지 않는다.
        headButton("옮기기", filled: true, disabled: count == 0, action: onMove)
        headButton("지우기", destructive: true, disabled: count == 0, action: onRemove)
        headButton("마치기", action: onDone)
    }

    /// 머리줄의 단추. 강조는 반전 하나로만 — 지금 하려던 일이 채워진다.
    private func headButton(_ title: String, filled: Bool = false, destructive: Bool = false,
                            disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.korean(13.5, weight: filled ? .medium : .regular))
                // **접히지 않는다.** 자리가 모자랄 때 접히라고 두면 알약이 동그라미가 된다.
                // 모자라면 줄을 나눌 일이지 글자를 접을 일이 아니다.
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, filled ? 14 : 6)
                .padding(.vertical, filled ? 8 : 0)
                .background(filled ? Theme.ink : .clear, in: Capsule())
                .foregroundStyle(filled ? Theme.paper : (destructive ? Color.red : Theme.grey1))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
    }
}
