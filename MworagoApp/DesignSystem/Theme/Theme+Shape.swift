import SwiftUI

/// 아이콘 크기 사다리와 모서리 반경.
extension Theme {
    // MARK: 아이콘 크기
    //
    // **글자처럼 아이콘도 숫자로 적지 않는다.** SF Symbol 크기가 8 · 9 · 10 · 11 · 12 · 13 ·
    // 15 · 20 · 21 의 아홉 값으로 스물네 곳에 박혀 있었다. 1pt 차이는 위계로 읽히지 않고
    // 어긋난 값으로 보인다는 것은 글자 사다리에서 이미 겪은 일이라, 같은 규칙을 따라
    // 다섯 계단으로 접었다(8·10 → 9 · 10·12 → 11 또는 13 · 20 → 21).

    /// 아이콘 크기 한 계단. 자리의 이름이지 숫자가 아니다.
    enum IconSize: CGFloat {
        /// 글줄 곁에 붙는 가장 작은 표시 — 고르는 단추의 `⌄`, 알림 줄 끝의 `›`.
        case caret = 9
        /// 목록 줄 끝의 `›`, 글줄 사이의 화살.
        case chevron = 11
        /// 메뉴 줄 · 더하기 · 지우기처럼 글자와 나란히 서는 손잡이.
        case action = 13
        /// 혼자 서서 눌리는 손잡이 — 갈피표 · 소리 · 더보기.
        case control = 15
        /// 줄 앞의 표시 — 고르기 · 빼기 동그라미, 온보딩의 탭 지도.
        case mark = 21
    }

    static func icon(_ size: IconSize, weight: Font.Weight = .regular) -> Font {
        .system(size: size.rawValue, weight: weight)
    }

    // MARK: 모서리 반경
    //
    // 반경도 다섯 자리에서 숫자로 적혀 있었다. 같은 숫자가 같은 물건을 가리키도록 이름을 붙인다.

    enum Radius {
        /// 카드와 가운데 판 — 가장 큰 덩어리.
        static let card: CGFloat = 22
        /// 화면 안에 띄운 메뉴 판.
        static let menu: CGFloat = 20
        /// 입력 바.
        static let bar: CGFloat = 18
        /// 판 안의 입력칸.
        static let field: CGFloat = 10
        /// 문장 조각 하나를 감싸는 반전.
        static let piece: CGFloat = 7
    }
}

extension Animation {
    /// 고르고 펼치고 접는 몸짓 — 탭 하나에 화면이 바뀌는 자리의 기본 움직임.
    ///
    /// 열아홉 자리가 `.snappy(duration: 0.18)` 을 각자 적고 있었다. 이 값이 하나여야
    /// 화면을 옮겨 다녀도 같은 손맛이다. 카드 뒤집기(`Flip.motion`)처럼 일부러 다른
    /// 몸짓은 제 이름을 따로 갖는다.
    static let select: Animation = .snappy(duration: 0.18)
}
