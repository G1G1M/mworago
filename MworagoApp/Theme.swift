import SwiftUI

/// 흰검 한 벌.
///
/// 색으로 뜻을 나누지 않는다. **강조는 반전 하나로만** 한다 —
/// 검게 채워진 것은 지금 고른 것, 그뿐이다.
enum Theme {
    static let ink = Color(red: 0.09, green: 0.09, blue: 0.09)      // #171717
    static let paper = Color(red: 0.99, green: 0.99, blue: 0.98)

    static let grey1 = Color(white: 0.28)   // 본문 다음으로 진한 것
    static let grey2 = Color(white: 0.48)   // 읽기·부가 정보
    static let grey3 = Color(white: 0.70)   // 구분선·비활성
    static let grey4 = Color(white: 0.92)   // 면

    /// 일본어는 Zen Maru Gothic. 둥근 고딕이라 딱딱하지 않고, 가나가 화면의 얼굴인 이 앱에 맞는다.
    static func japanese(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(weight == .regular ? "ZenMaruGothic-Regular" : "ZenMaruGothic-Medium", size: size)
    }

    /// 한글은 고운돋움. 굵기가 하나뿐이라 위계는 크기와 색으로 만든다.
    static func korean(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("GowunDodum-Regular", size: size)
    }
}
