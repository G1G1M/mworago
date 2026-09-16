import SwiftUI

/// 탭바 지도. 다섯 자리가 늘 서 있고 **지금 장의 것만 검게 채워진다.**
///
/// 강조는 반전 하나로만 한다 — 채워진 것이 지금 말하는 자리다. 앱의 다른 곳
/// (설정의 `모습`, 책장의 보기 다이얼, 탭바의 고른 칸)이 다 같은 문법을 쓴다.
///
/// **아이콘 크기는 바뀌지 않는다.** 포커스를 크기로도 말하면 장을 넘길 때마다
/// 줄의 높이가 흔들려, 아래 글이 위아래로 뛴다. 채우는 것 하나로 충분하다.
///
/// **눌러서도 간다.** 지도가 "어디에 무엇이 있는지"를 말하는 그림이기만 하면,
/// 눌러 본 사람에게는 아무 일도 안 일어나는 그림이다. 다섯 자리가 곧 다섯 장이라
/// 짚은 자리로 바로 넘어간다 — 뒤로 가는 길이 `이전` 하나뿐이던 것도 함께 풀린다.
struct OnboardingTabMap: View {
    /// 지금 장이 가리키는 탭.
    let focusedTab: Int
    /// 짚은 탭. 그 탭의 장으로 넘기는 일은 온보딩이 한다.
    let onPick: (Int) -> Void

    var body: some View {
        // **사이를 단추가 나눠 갖는다.** 칸 사이 18pt 를 좌우 9pt 씩 단추 안으로 넣으면
        // 줄의 폭도, 알약이 서는 자리도 그대로인데 누를 수 있는 넓이만 46 → 64pt 가 된다.
        HStack(alignment: .top, spacing: 0) {
            ForEach(OnboardingPage.tabs.indices, id: \.self) { i in
                let focused = i == focusedTab
                Button { onPick(i) } label: {
                    VStack(spacing: 9) {
                        Image(systemName: OnboardingPage.tabs[i].symbol)
                            .font(.system(size: 21))
                            .foregroundStyle(focused ? Theme.paper : Theme.grey3)
                            .frame(width: 46, height: 36)
                            .background(focused ? Theme.ink : .clear, in: Capsule())
                        Text(OnboardingPage.tabs[i].name)
                            .font(Theme.korean(.tag))
                            .foregroundStyle(focused ? Theme.ink : Theme.grey3)
                    }
                    .padding(.horizontal, Self.tabGap / 2)
                    // 알약과 글자 사이의 빈 자리까지 한 단추다. 없으면 그 틈에서 손이 샌다.
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(OnboardingPage.tabs[i].name)
                .accessibilityAddTraits(focused ? [.isSelected] : [])
            }
        }
        // 알약은 도형이라 제 여백이 없어 글보다 밖에서 선다. 스크린샷을 픽셀로 재서 당긴다.
        // 단추가 안으로 9pt 를 물었으므로 그만큼 되돌려야 알약이 재 둔 자리에 그대로 선다.
        .padding(.leading, -Self.mapLeading - Self.tabGap / 2)
    }

    /// 지도의 칸과 칸 사이(pt). 절반씩 양옆 단추가 나눠 갖는다.
    private static let tabGap: CGFloat = 18

    /// 지도가 글보다 밖에서 시작하는 만큼(pt). 음수라 안쪽으로 민다.
    ///
    /// 알약은 도형이라 글리프가 안고 있는 여백이 없어, 기둥에 정확히 붙어 선다(24.0pt).
    /// 제목은 글자라 제 여백만큼 안에서 시작한다(25.7pt). 그 차이를 재서 넣는다 —
    /// 아이콘이나 알약 크기를 바꾸면 다시 재야 한다.
    private static let mapLeading: CGFloat = -1.7
}
