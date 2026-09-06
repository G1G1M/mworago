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
    static let grey3 = adaptive(light: .init(white: 0.70), dark: .init(white: 0.50))  // 구분선·비활성
    // 어두운 바탕에서 0.40 은 배경과 3.3:1 밖에 안 벌어져, 구분선이 아니라 **정보**를
    // 담을 때(묶음 줄의 낱말 미리보기 · 개수) 묻혀 버렸다. 0.50 이면 4.4:1 이다.
    static let grey4 = adaptive(light: .init(white: 0.92), dark: .init(white: 0.18))  // 면

    /// 이 앱이 쓰는 말.
    ///
    /// **날짜가 기기 언어를 따라가고 있었다.** 영어로 맞춰 둔 기기에서는
    /// `September 1` 이 떴다 — 화면의 다른 글자는 다 한국어인데 날짜만 영어였다.
    ///
    /// 아직 여러 말로 옮기지 않았으므로 한국어로 못 박는다. 여러 말을 받게 되면
    /// 이 한 줄을 걷어내면 된다 — 그때는 기기 언어를 따르는 것이 맞다.
    /// 일본어는 자료 자체가 일본어라 이것과 무관하다.
    static let locale = Locale(identifier: "ko_KR")

    /// 지우는 일 하나에만 쓰는 색.
    ///
    /// **이 앱에서 뜻을 지고 있는 색은 이것뿐이다.** 나머지는 흰검과 회색 넷으로만 간다.
    /// 되돌릴 수 없는 일은 눌리기 전에 그렇다고 말해 주어야 하고, 반전으로는 그 말을
    /// 할 수 없다 — 채워진 것은 이미 "지금 고른 것"이라는 뜻을 갖고 있다.
    /// 두 자리(책장의 빼기 · 고르기 머리줄의 지우기)에서 각자 `Color.red` 를 부르고
    /// 있었으므로, 예외인 채로 한 자리에 모아 둔다.
    static let destructive = Color.red

    /// 입력 바의 자리표시 글자.
    ///
    /// **시스템이 정하는 색이다.** `TextField` 의 자리표시는 `foregroundStyle` 을 따르지
    /// 않고 이 색으로 그려진다 — 회색 넷 중 아무거나 골라 흉내 내면 반드시 어긋난다.
    /// 스플래시의 마지막 한 프레임이 진짜 입력 바와 같아야 하므로, 같은 자리에서 가져온다.
    static let placeholder = Color(uiColor: .placeholderText)

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

    /// 밝기에 따라 갈리는 색 하나.
    ///
    /// 색마다 두 값을 한 줄에 나란히 적어 둔다. 밝은 벌과 어두운 벌을 다른 곳에 두면
    // MARK: 선
    //
    // **선을 긋는 방법이 셋이었다.** `Divider().overlay(색)` · 맨 `Divider()` ·
    // `Rectangle().fill(색).frame(height: 0.5)` 가 화면마다 섞여 있었다. `Divider` 는
    // 제 두께와 블렌드를 시스템에서 가져오므로 같은 색을 얹어도 `Rectangle` 과 같은
    // 진하기로 그려지지 않는다 — 탭을 옮길 때 선만 미묘하게 달라 보인다.
    //
    // 그어지는 굵기를 한 자리에서 정한다. 0.5pt 는 2배 화면에서 1px 이다.

    /// 가로로 긋는 실선 하나. **선은 여기서만 그린다.**
    static func rule(_ color: Color = grey3) -> some View {
        Rectangle().fill(color).frame(height: ruleWidth)
    }

    /// 선 하나의 굵기.
    static let ruleWidth: CGFloat = 0.5

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

    /// 빈 화면의 글 덩어리가 서는 자리의 높이.
    ///
    /// **두 빈 화면(책장 · 연습)의 첫 줄을 같은 높이에 세우려고 둔 값이다.** 덩어리마다
    /// 줄 수가 달라서, 덩어리를 통째로 가운데 두면 긴 쪽과 짧은 쪽의 **첫 줄이 그 높이
    /// 차이의 절반만큼 어긋난다**(책장 123 · 연습 86 이라 18pt 가 어긋났다). 탭을 오갈 때
    /// 같은 자리에 있어야 할 말이 위아래로 흔들린다.
    ///
    /// 그래서 덩어리가 아니라 **이 높이의 자리를 가운데 두고, 글은 그 자리 위쪽에 붙인다.**
    /// 첫 줄은 어느 화면에서나 같은 곳에서 시작하고, 짧은 쪽은 아래가 남을 뿐이다.
    /// **가장 긴 덩어리가 들어갈 만큼은 되어야 한다** — 넘치는 화면만 아래로 자라서
    /// 그 화면의 첫 줄이 다시 어긋난다. 아이폰처럼 폭이 좁으면 설명 줄이 접혀 덩어리가
    /// 길어지므로(책장 기준 아이패드 96 · 아이폰 136) 그쪽에 맞춰 잡는다.
    static let emptyBlockHeight: CGFloat = 150

    /// 화면 맨 위·맨 아래 여백.
    static let screenTop: CGFloat = 18
    static let screenBottom: CGFloat = 36

    /// 한쪽만 고치고 지나가기 쉽고, 그러면 어느 한쪽에서만 대비가 무너진다.
    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

/// 내비 바에 뜨는 화면 이름을 **앱 서체로** 그린다.
///
/// `navigationTitle` 은 시스템이 제 글꼴(SF)로 그린다. 화면 안의 글은 모두 고운돋움인데
/// 맨 위 이름 하나만 다른 글씨면, 그 줄만 남의 화면에서 옮겨 온 것처럼 보인다.
///
/// **`navigationTitle` 도 함께 남긴다.** 눈에는 이 `principal` 이 보이지만, 뒤로 버튼이
/// 가져다 쓰는 이름은 여전히 `navigationTitle` 이다. 지우면 뒤로 버튼이 이름을 잃는다.
struct KoreanNavigationTitle: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(Theme.korean(.title, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
            }
    }
}

extension View {
    /// 화면 이름을 앱 서체로 그린다. `navigationTitle` 대신 쓴다.
    func koreanNavigationTitle(_ title: String) -> some View {
        modifier(KoreanNavigationTitle(title: title))
    }
}

private extension UIColor {
    convenience init(white: CGFloat) { self.init(white: white, alpha: 1) }
    convenience init(red: CGFloat, green: CGFloat, blue: CGFloat) {
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}
