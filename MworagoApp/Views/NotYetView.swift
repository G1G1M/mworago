import SwiftUI

/// 아직 만들지 않은 자리.
///
/// **가짜 화면을 그리지 않는다.** 그럴듯한 목록과 빈 카드를 늘어놓으면 "내 것이 왜 없지"로
/// 읽히고, 없는 기능을 있는 것처럼 약속하게 된다. 무엇이 올 자리인지 한 줄로 말하고
/// 왜 아직 없는지 덧붙이는 편이 정직하고, 읽는 사람도 기다릴지 말지 정할 수 있다.
struct NotYetView: View {
    let title: String
    let line: String
    let detail: String

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(Theme.korean(26, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(line)
                    .font(Theme.korean(16))
                    .foregroundStyle(Theme.grey1)
                Text(detail)
                    .font(Theme.korean(14))
                    .foregroundStyle(Theme.grey2)
                    .fixedSize(horizontal: false, vertical: true)

                Text("아직 만들지 않았습니다")
                    .font(Theme.korean(12))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.grey4, in: Capsule())
                    .foregroundStyle(Theme.grey1)
                    .padding(.top, 4)
            }
            .frame(maxWidth: 460, alignment: .leading)
            .padding(.horizontal, 28)
        }
    }
}
