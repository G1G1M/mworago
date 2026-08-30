import SwiftUI

/// 흰검 한 벌.
///
/// 색으로 뜻을 나누지 않는다. **강조는 반전 하나로만** 한다 —
/// 검게 채워진 것은 지금 고른 것, 그뿐이다.
///
/// 어두울 때는 같은 한 벌을 뒤집는다. `ink` 와 `paper` 가 자리를 바꾸고 회색 넷이 뒤따르므로,
/// 반전 강조는 손대지 않아도 그대로 성립한다 — 어두운 화면에서는 밝게 채워진 것이 고른 것이다.
enum Theme {
    /// 글씨. 밝을 때 #171717, 어두울 때는 순백을 피한다 — 검은 바탕에 흰 글씨는 번져 보인다.
    static let ink = adaptive(light: .init(white: 0.09), dark: .init(white: 0.93))
    /// 바탕. 밝을 때 살짝 따뜻한 흰색, 어두울 때 순검을 피한다 — OLED 의 검정은 경계가 너무 날카롭다.
    static let paper = adaptive(light: .init(red: 0.99, green: 0.99, blue: 0.98),
                                dark: .init(white: 0.07))

    static let grey1 = adaptive(light: .init(white: 0.28), dark: .init(white: 0.78))  // 본문 다음으로 진한 것
    static let grey2 = adaptive(light: .init(white: 0.48), dark: .init(white: 0.60))  // 읽기·부가 정보
    static let grey3 = adaptive(light: .init(white: 0.70), dark: .init(white: 0.40))  // 구분선·비활성
    static let grey4 = adaptive(light: .init(white: 0.92), dark: .init(white: 0.18))  // 면

    /// 일본어는 Zen Maru Gothic. 둥근 고딕이라 딱딱하지 않고, 가나가 화면의 얼굴인 이 앱에 맞는다.
    static func japanese(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(weight == .regular ? "ZenMaruGothic-Regular" : "ZenMaruGothic-Medium", size: size)
    }

    /// 한글은 고운돋움. 굵기가 하나뿐이라 위계는 크기와 색으로 만든다.
    static func korean(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("GowunDodum-Regular", size: size)
    }

    /// 밝기에 따라 갈리는 색 하나.
    ///
    /// 색마다 두 값을 한 줄에 나란히 적어 둔다. 밝은 벌과 어두운 벌을 다른 곳에 두면
    /// 한쪽만 고치고 지나가기 쉽고, 그러면 어느 한쪽에서만 대비가 무너진다.
    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

private extension UIColor {
    convenience init(white: CGFloat) { self.init(white: white, alpha: 1) }
    convenience init(red: CGFloat, green: CGFloat, blue: CGFloat) {
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}
