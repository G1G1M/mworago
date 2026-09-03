import SwiftUI

@main
struct MworagoApp: App {

    /// 앱이 사는 동안 한 번만 선다. **화면이 아니라 여기가 조립하는 자리다** —
    /// 예전에는 뿌리 화면이 모은 낱말을, 찾기 화면이 검색기와 옮긴 말을 각자 만들었다.
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView(preferences: container.preferences)
                // 화면 여럿이 같은 것을 본다. 넘겨 가며 나르지 않고 환경에 얹는다 —
                // 찾기 카드처럼 깊이 있는 자리까지 손으로 나르면 중간 화면이 제가
                // 쓰지도 않는 것을 인자로 받게 된다.
                .environment(container.collection)
                .environment(container.engine)
                .environment(container.desk)
        }
    }
}

// **`horizontalSizeClass` 를 덮어쓰지 않는다.**
//
// 아이패드에서도 아이폰처럼 탭바를 아래에 두려고 여기서 `.compact` 로 속였다.
// 대가는 **화면이 두 벌 그려지는 것**이었다 — `TabView` 를 감싼 UIKit 컨테이너는 제 자리를
// 진짜 사이즈 클래스로 정하고 그 안의 SwiftUI 만 속은 값을 받아서, 위(아이패드의 자리)와
// 아래(속은 자리)에 각각 한 벌씩 선다. 온보딩처럼 화면을 통째로 덮는 자리에서는
// "건너뛰기"가 위아래로 두 번 보였다.
//
// 속인 까닭이었던 "아이패드 상단 탭바는 시스템이 글자만 그린다"는 **더는 사실이 아니다.**
// iPadOS 26 의 떠 있는 탭바는 아이콘을 그대로 그린다(`Tab` 의 라벨이 심볼이므로).
// 그래서 속일 이유가 없어졌고, 표준 컨트롤은 제자리에 두는 편이 낫다 —
// 자리 · 손대기 좋은 크기 · 손쉬운 사용을 시스템이 준다.
