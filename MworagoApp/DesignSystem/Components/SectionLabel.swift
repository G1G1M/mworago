import SwiftUI

/// 갈래 이름 — 작은 이름표와 그 아래 얇은 선.
///
/// 섹션 이름은 **작은 라벨**로 물러나고 그 아래 얇은 선이 갈래를 가른다.
/// 이름을 본문만큼 키우면 그 아래 항목과 섞여서, 무엇이 묶음이고 무엇이 항목인지
/// 눈이 매번 다시 판단해야 한다.
///
/// 네 화면(설정 · 오십음도 · 글자 상세 · 치는 법)이 같은 꼴을 각자 그리고 있었고,
/// 그중 하나는 선을 `Rectangle` 로 직접 그려 놓이는 자리에 따라 1px · 2px 로 갈렸다.
struct SectionLabel: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.lineGap) {
            Text(title)
                .font(Theme.korean(.tag))
                .tracking(0.6)
                .foregroundStyle(Theme.grey2)
            Theme.rule()
        }
    }
}
