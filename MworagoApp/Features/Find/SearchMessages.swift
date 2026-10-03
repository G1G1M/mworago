import SwiftUI

// 답이 없을 때 입력 바 위에 서는 글. 치기 전 안내와, 못 찾았거나 사전을 못 열었을 때의 알림.

/// 아직 아무것도 안 쳤을 때의 안내.
struct SearchPrompt: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // **온보딩 첫 장과 같은 말을 쓴다.** 한 번 읽고 온 사람이 여기서 다른 말을
            // 만나면 처음부터 다시 이해해야 한다. "들린 대로 치세요"는 무엇을 치라는
            // 것인지가 빠져 있어 실제로 안 읽혔다.
            Text("일본어를 들리는 대로 쳐보세요")
                .font(Theme.korean(.hero, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("띄어 쓰지 않아도 돼요. 어디서 끊을지는 사전이 정해요.")
                .font(Theme.korean(.body))
                .foregroundStyle(Theme.grey2)
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, 24)
    }
}

/// 답 대신 서는 알림 — 무엇이 안 됐는지 한 줄, 어떻게 하면 되는지 한 줄.
struct SearchNotice: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(Theme.korean(.title, weight: .medium)).foregroundStyle(Theme.ink)
            Text(detail).font(Theme.korean(.body)).foregroundStyle(Theme.grey2)
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, 24)
    }
}
