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
    // MARK: 간격
    //
    // **숫자를 화면마다 직접 쓰지 않는다.** 눈대중으로 맞추면 그때는 비슷해 보여도
    // 화면을 옮길 때 글 시작점이 미세하게 움직인다. 실제로 좌우 여백이 20·24·28·32 로,
    // 최대 폭이 460·520·640 으로 갈려 있었다. 색과 서체가 그렇듯 간격도 한 자리에 두고
    // 이름으로 꺼내 쓴다 — 이름이 있으면 무엇과 무엇이 같은 뜻인지도 드러난다.

    /// 화면 좌우 여백. 어느 화면에서도 글은 여기서 시작한다.
    static let gutter: CGFloat = 24
    /// 섹션과 섹션 사이. **묶인 것은 붙고 다른 것은 떨어진다** — 그 대비를 만드는 값이라
    /// 아래 둘보다 뚜렷하게 커야 한다.
    static let sectionGap: CGFloat = 34
    /// 한 섹션 안의 덩어리 사이.
    static let blockGap: CGFloat = 18
    /// 붙어 있는 줄 사이 — 제목과 부제처럼 한 덩어리로 읽히는 것.
    static let lineGap: CGFloat = 7

    /// 읽는 화면의 최대 폭. 한 줄이 너무 길면 다음 줄 첫머리를 눈이 놓친다.
    static let readWidth: CGFloat = 560
    /// 목록 화면의 최대 폭. 훑는 화면이라 한 번에 많이 들어오는 편이 낫다.
    static let listWidth: CGFloat = 640

    /// 화면 맨 위·맨 아래 여백.
    static let screenTop: CGFloat = 18
    static let screenBottom: CGFloat = 36

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
