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

    // MARK: 선
    //
    // **선을 긋는 방법이 셋이었다.** `Divider().overlay(색)` · 맨 `Divider()` ·
    // `Rectangle().fill(색).frame(height: 0.5)` 가 화면마다 섞여 있었다. `Divider` 는
    // 제 두께와 블렌드를 시스템에서 가져오므로 같은 색을 얹어도 `Rectangle` 과 같은
    // 진하기로 그려지지 않는다 — 탭을 옮길 때 선만 미묘하게 달라 보인다.
    //
    // 그어지는 굵기를 한 자리에서 정한다. 0.5pt 는 2배 화면에서 1px 이다.

    /// 가로로 긋는 실선 하나. **선은 여기서만 그린다.**
    static func rule(_ color: Color = grey3) -> some View { Rule(color: color) }

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
