import SwiftUI

/// 지금 무엇을 연습하고 있는지. 전체가 아니라면 그 사실이 화면에 있어야 한다 —
/// 몇 장 넘기다 보면 어디서 온 묶음인지 잊는다.
struct PracticeSubsetBanner: View {
    /// 들고 온 하루치의 이름 — 그날의 날짜다.
    let label: String
    let count: Int
    /// 하루치에서 빠져나와 전체로 돌아간다.
    let onClear: () -> Void

    var body: some View {
        VStack {
            HStack(spacing: 10) {
                Text(label)
                    .font(Theme.korean(.sub, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text("\(count)개")
                    .font(Theme.korean(.sub))
                    .foregroundStyle(Theme.grey2)
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
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.grey3.opacity(0.5), lineWidth: 0.5))
            .padding(.top, 14)
            Spacer()
        }
    }
}
