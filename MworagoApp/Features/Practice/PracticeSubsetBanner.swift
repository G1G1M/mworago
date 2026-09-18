import SwiftUI

/// 지금 무엇을 연습하고 있는지. 전체가 아니라면 그 사실이 화면에 있어야 한다 —
/// 몇 장 넘기다 보면 어디서 온 묶음인지 잊는다.
///
/// **머리줄 안에 선다.** 한때 화면 위에 덧띄웠는데, `연습 1 / 4` 와 같은 높이라
/// 그 숫자를 덮었다. 연습 탭에서 고르는 단추(`PracticeScopeButton`)가 서던 자리가
/// 곧 "지금 무엇을 보는가"의 자리이므로, 책장에서 들고 왔을 때도 같은 자리에 둔다.
struct PracticeSubsetBanner: View {
    /// 들고 온 하루치의 이름 — 그날의 날짜다.
    let label: String
    let count: Int
    /// 하루치에서 빠져나와 전체로 돌아간다.
    let onClear: () -> Void

    var body: some View {
        // 글자를 키운 사람에게는 개수를 접는다. 셋을 다 붙들면 묶음 이름이 `리…` 로 잘려,
        // 이 알약이 하려는 말(어느 묶음을 보는가)만 사라진다.
        ViewThatFits(in: .horizontal) {
            row(showsCount: true)
            row(showsCount: false)
        }
    }

    private func row(showsCount: Bool) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(Theme.korean(.sub))
                .foregroundStyle(Theme.ink)
                // 긴 묶음 이름은 자른다. 이 줄에는 `연습 1 / 4` 가 먼저 서 있다.
                .lineLimit(1)
                .truncationMode(.tail)
            if showsCount {
                Text("\(count)개")
                    .font(Theme.korean(.sub))
                    .foregroundStyle(Theme.grey2)
                    .monospacedDigit()
            }
            Button(action: onClear) {
                Text("전체")
                    .font(Theme.korean(.sub))
                    .foregroundStyle(Theme.grey2)
            }
            .buttonStyle(.plain)
            .accessibilityHint("모은 낱말 전체를 연습합니다")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        // 찾기의 입력 바 · 담은 자리 알림과 같은 유리다. 이 자리에서 떠 있는 것은 셋뿐이다.
        .glassCapsule()
    }
}
