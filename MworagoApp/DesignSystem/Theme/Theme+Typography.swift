import SwiftUI

/// 글꼴 두 벌(일본어 · 한국어)과 크기 사다리.
extension Theme {
    // MARK: 글자 크기
    //
    // **화면마다 숫자를 직접 쓰지 않는다.** 한글이 11 · 11.5 · 12 · 13 · 13.5 · 14 · 15 ·
    // 16 · 17 · 19 · 20 · 22 · 24 · 26 · 34 의 **열다섯 값**으로 갈려 있었다. 그중 여럿은
    // 같은 자리를 가리키는 다른 숫자였다 — 목록 한 줄에 선 낱말이 책장에서는 24, 묶음
    // 안에서는 21 이었고, 눌러서 고르는 줄과 단추의 글씨는 13.5 · 15 · 16 · 17 로 넷이었다.
    // 색과 서체와 간격이 그렇듯 크기도 한 자리에 두고 이름으로 꺼내 쓴다.
    //
    // **한 계단은 최소 2pt 다.** 1pt 차이는 위계로 읽히지 않고 어긋난 값으로 보인다 —
    // 문장의 뜻이 17 이라 발음(16)보다 1 만 컸을 때 이미 겪은 일이고, 그래서 16 으로
    // 내렸었다. 사이 값을 못 쓰게 하려고 크기를 숫자가 아니라 이 사다리로만 받는다.

    /// 글자 크기 한 계단. 자리의 이름이지 숫자가 아니다.
    enum Size: CGFloat {
        /// 꼬리표와 절 이름표 — `품사` · `지금` · `새 묶음` · `뜻` · `담은 날`.
        case tag = 11
        /// 보조 — 설명의 둘째 줄 · 개수 · 한글 읽기.
        case sub = 13
        /// 본문. 설명 줄과 단추와 눌러서 고르는 줄이 모두 여기다.
        case body = 15
        /// 줄 제목 · 판 제목 · 내비 바의 화면 이름.
        case title = 17
        /// 입력 바. **스플래시의 마지막 프레임이 이것과 같아야 한다** —
        /// 그래서 이 칸을 쓰는 곳은 그 둘뿐이고, 다른 자리가 여기 올라오면 짝이 깨진다.
        case field = 19
        /// 그 화면(또는 카드)에서 가장 먼저 읽히는 줄.
        /// 화면 이름 · 빈 화면의 첫 줄 · 연습 카드의 뜻이 한 크기다.
        case heading = 22
        /// 목록 한 줄에 선 낱말(일본어) · 가나표의 칸.
        case word = 24
        /// 화면 하나를 여는 큰 말 — 온보딩의 장 제목 · 찾기의 첫 화면 · 조각 카드의 낱말.
        case hero = 26
        /// 그 화면이 보여 주려는 것 하나 — 낱말 상세의 낱말 · 연습 카드의 앞면 ·
        /// 뒤집은 가나 카드의 답.
        case display = 34
        /// 문장 머리에 늘어선 조각.
        case piece = 44
        /// 뒤집은 가나 카드의 작아진 앞면.
        case cardBack = 56
        /// 가나 한 자를 크게.
        case glyph = 84
        /// 가나 카드의 앞면. 이 앱에서 가장 큰 글자다.
        case cardFront = 180

        /// **곁에 붙는 글자의 크기.** 가나 옆 괄호 안의 한자가 이것을 쓴다.
        ///
        /// 사다리가 고른 간격이 아니라 계단 수로는 못 센다 — 26 의 한 계단 아래는
        /// 24 라 거의 같은 크기로 보이고, 34 의 한 계단 아래는 26 이라 너무 크다.
        /// **약 70% 자리를 골랐다.** 딸린 글자로 읽히면서 한자가 뭉개지지 않는
        /// 가장 작은 자리다(한자는 획이 많아 가나보다 일찍 무너진다).
        var beside: Size {
            switch self {
            case .display: .word          // 34 → 24
            case .hero: .field            // 26 → 19
            case .word: .title            // 24 → 17
            case .heading: .body          // 22 → 15
            case .title: .sub             // 17 → 13
            default: .tag                 // 그 밖에는 사다리의 맨 아래
            }
        }
    }

    /// 일본어는 Zen Maru Gothic. 둥근 고딕이라 딱딱하지 않고, 가나가 화면의 얼굴인 이 앱에 맞는다.
    static func japanese(_ size: Size, weight: Font.Weight = .regular) -> Font {
        japanese(growing: size.rawValue, weight: weight)
    }

    /// 사다리 밖에서 **자라나는** 글자.
    ///
    /// 스플래시의 `あ` 하나만 이 문을 쓴다 — 화면 크기에 맞춰 값이 계산되므로
    /// 계단 위에 놓을 수가 없다. 그 밖에는 `Size` 로만 받는다.
    static func japanese(growing size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(weight == .regular ? "ZenMaruGothic-Regular" : "ZenMaruGothic-Medium", size: size)
    }

    /// 이 글자열을 이어서 그릴 때의 폭.
    ///
    /// **`Text` 는 제 크기를 재면서 좌우에 여유를 둔다.** 조각을 따로 그려 이어 붙이면
    /// 그 여유가 조각마다 두 번씩 끼어들어, 한 문장인데 조각 경계에서만 자간이 벌어진다.
    /// 일본어는 띄어 쓰지 않으므로 그 틈이 곧 **없는 띄어쓰기**로 읽힌다 —
    /// 되살린 문장이 원문과 다른 곳에서 끊겨 보이는 셈이다.
    ///
    /// 그래서 글자가 실제로 차지하는 폭을 재어 자리를 그만큼만 준다.
    /// **사용자가 정한 글자 크기를 함께 따른다.** `Font.custom(_:size:)` 는 Dynamic Type
    /// 을 따라 커지는데 폭만 고정 크기로 재면, 글자는 커지고 자리는 그대로라 조각이
    /// 겹치거나 잘린다. 자간을 맞추려고 넣은 것이 글자를 키운 사람에게는 더 나쁜 화면이 된다.
    static func japaneseWidth(_ text: String, size: Size, weight: Font.Weight = .regular) -> CGFloat {
        let name = weight == .regular ? "ZenMaruGothic-Regular" : "ZenMaruGothic-Medium"
        let size = size.rawValue
        let base = UIFont(name: name, size: size) ?? .systemFont(ofSize: size)
        let scaled = UIFontMetrics.default.scaledFont(for: base)
        return (text as NSString).size(withAttributes: [.font: scaled]).width
    }

    /// 이 한글이 차지하는 폭. `japaneseWidth` 와 같은 방식이다.
    ///
    /// 글자 수가 달라지는 버튼(`다음` / `시작하기`)에 자리를 미리 잡아 줄 때 쓴다.
    /// 사용자가 정한 글자 크기를 함께 따르므로, 글자를 키워도 자리가 어긋나지 않는다.
    static func koreanWidth(_ text: String, size: Size) -> CGFloat {
        let size = size.rawValue
        let base = UIFont(name: "GowunDodum-Regular", size: size) ?? .systemFont(ofSize: size)
        let scaled = UIFontMetrics.default.scaledFont(for: base)
        return (text as NSString).size(withAttributes: [.font: scaled]).width
    }

    /// 한글은 고운돋움. 굵기가 하나뿐이라 위계는 크기와 색으로 만든다.
    ///
    /// **숫자가 아니라 사다리 한 칸을 받는다.** 숫자를 받던 동안 같은 자리가 화면마다
    /// 다른 값으로 적혔고, 그 어긋남은 한 화면만 보아서는 보이지 않았다.
    static func korean(_ size: Size, weight: Font.Weight = .regular) -> Font {
        .custom("GowunDodum-Regular", size: size.rawValue)
    }
}
