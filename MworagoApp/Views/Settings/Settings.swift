import SwiftUI
import UIKit
import MworagoCore

/// 앱을 밝게 볼지 어둡게 볼지.
///
/// **"화면"이라 부르지 않는다.** 그 말은 기기의 스크린을 가리켜서, 밝기 설정처럼
/// 들린다 — 여기서 정하는 것은 이 앱이 입는 옷이다. 그래서 `모습`이라 적는다.
/// `책장` · `묶음` · `갈피표`처럼 이 앱이 쓰는 말의 결과도 맞는다.
///
/// 기본은 **기기를 따르는 것**이다. 자막을 보면서 쓰는 앱이라 밤에 켤 일이 많고,
/// 그때마다 앱에서 따로 바꾸게 하면 번거롭다. 다만 이 앱은 흰검 한 벌이라
/// 밝기가 인상을 크게 바꾸므로, 고정하고 싶은 사람에게 길은 열어 둔다.
///
/// **적어 두는 일은 이 타입이 하지 않는다.** 어디에 어떻게 남길지는 밖에서 받는다
/// (`PreferenceStoring`). 예전에는 여기서 `FileManager` 로 Application Support 를
/// 찾았는데, 같은 여섯 줄이 온보딩 표시·모은 낱말 자리에도 복붙되어 있었고
/// 화면을 세우지 않고는 그 길을 밟을 수 없었다.
///
/// `UserDefaults` 를 쓰지 않는 까닭은 `PreferenceStoring` 에 적어 두었다.
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "기기 따라"
        case .light: "밝게"
        case .dark: "어둡게"
        }
    }

    /// `nil` 이면 기기를 따른다.
    var scheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    /// 적어 둘 때 쓰는 이름.
    static let key = "appearance"

    /// 적힌 것이 없거나 읽을 수 없으면 기기를 따른다.
    static func saved(in preferences: some PreferenceStoring) -> Appearance {
        guard let raw = preferences.string(forKey: key),
              let value = Appearance(rawValue: raw)
        else { return .system }
        return value
    }

    func save(in preferences: some PreferenceStoring) {
        preferences.set(rawValue, forKey: Self.key)
    }
}

/// 설정.
///
/// **도움말 안에 있던 것을 여기로 옮겼다.** 자료 출처는 라이선스가 요구하는 표시라
/// 어디엔가 반드시 있어야 하는데, "한글로 어떻게 치나" 쪽지 안 스크롤 아래에 있으면
/// 접근은 되어도 발견이 안 된다. 실제로 화면을 확인할 때조차 눈에 안 잡혔다.
///
/// 탭을 늘리지는 않았다. 탭 셋은 앱의 이야기(찾고·담기고·다시 만난다)이고
/// 설정은 그 밖의 것이라, 나란히 세우면 흐름이 어그러진다.
struct Settings: View {
    @Binding var appearance: Appearance
    /// 고른 모습을 어디에 적어 둘지. 조립 루트가 준다.
    let preferences: any PreferenceStoring

    // MARK: 이 화면의 간격
    //
    // **설정만 유난히 벌어져 있다.** 다른 화면은 한 가지를 여러 층으로 보여 주므로
    // 층 사이가 붙어야 한 낱말로 읽힌다. 여기 놓이는 것은 성격이 다른 덩어리다 —
    // 모습 · 앱에 대하여 · 무엇을 하지 않는지. 서로 붙으면 목록 하나로 보인다.
    //
    // "묶인 것은 붙고 다른 것은 떨어진다"는 규칙은 그대로고, 이 화면에서는 그 대비가
    // 더 커야 성립한다. 그래서 섹션 사이만 키우고 **섹션 안은 그대로 뒀다** —
    // 둘을 함께 키우면 다시 고르게 늘어서서 아무것도 묶이지 않는다.

    /// 섹션과 섹션 사이. `Theme.sectionGap`(34)보다 벌린다.
    private static let sectionGap: CGFloat = 44
    /// 줄 하나가 차지하는 위아래. 손대기 좋은 크기이기도 하다.
    private static let rowPadding: CGFloat = 17
    /// 내비게이션 바 아래 첫 섹션까지. 제목에 바로 붙으면 화면이 시작하지 않은 것처럼 보인다.
    private static let topPadding: CGFloat = 28

    var body: some View {
        NavigationStack {
            ScrollView {
                // **차례는 하는 일 → 아는 일이다.**
                //
                // 설정에 들어오는 까닭이 그 순서다 — 눈이 부셔서 어둡게 바꾸러 오고,
                // 틀린 것을 보고 말하러 오고, 이 앱이 무엇을 쓰는지 궁금해서 온다.
                // 앞의 둘은 **하러** 오는 것이고 마지막은 **읽으러** 오는 것이라,
                // 손대는 것을 위에 두고 읽는 것을 아래에 둔다.
                VStack(alignment: .leading, spacing: Self.sectionGap) {
                    // 곁말("고르지 않으면 기기 설정을 따릅니다")을 뺐다. 고르개에
                    // `기기 따라`가 이미 적혀 있고 그것이 골라져 있으므로, 같은 말을
                    // 두 자리에서 하는 셈이었다.
                    //
                    // **`모습` 이 아니라 `화면` 이다.** 모습은 무엇의 모습인지가 빠져
                    // 있어 앱의 성격을 고르는 자리처럼도 읽힌다. 여기서 고르는 것은
                    // 화면이 밝은가 어두운가 하나다.
                    section("화면") { dial }

                    // **틀린 것을 말할 자리.** 이 앱이 내놓는 것은 사전과 규칙이 함께
                    // 만들어 낸 답이라, 틀리는 자리가 반드시 있다 — 뜻이 어긋나거나,
                    // 문장이 엉뚱하게 갈리거나, 소리가 안 맞는다.
                    //
                    // **줄 둘을 늘어놓지 않고 화면 하나로 뺐다.** 보내는 길이 둘이고
                    // 둘의 차이를 말해 줘야 하는데(하나는 이름이 함께 가고 하나는 안
                    // 간다), 그 설명까지 여기 늘어놓으면 고르개 옆에 문단이 붙는다.
                    // 고르는 일이 있는 자리는 제 화면을 갖는다 — `이 앱이 쓰는 자료` 와
                    // 같은 결이다.
                    section("의견") {
                        NavigationLink { Feedback() } label: {
                            row("의견 보내기", detail: "메일 · 이름 없이")
                        }
                        .buttonStyle(.plain)
                    }

                    section("앱에 대하여") {
                        VStack(alignment: .leading, spacing: 0) {
                            NavigationLink { Credits() } label: {
                                row("이 앱이 쓰는 자료", detail: "사전 · 글꼴 · 라이선스")
                            }
                            .buttonStyle(.plain)

                            Rectangle().fill(Theme.grey3).frame(height: 0.5)

                            row("버전", detail: Feedback.appVersion, chevron: false)
                        }
                    }

                    // 계정도 서버도 없는 앱이라 약관에 적을 것이 사실상 없다.
                    // 없는 것을 있는 척 적기보다, 무엇을 하지 않는지를 적는다.
                    //
                    // **제목을 달지 않는다.** 이것은 고르거나 눌러 들어갈 것이 아니라
                    // 화면을 닫으며 남기는 말이다. 지붕을 씌우면 위의 구역들과 같은
                    // 무게가 되어 "여기서도 무언가 할 수 있다"고 말하게 된다.
                    //
                    // **짧게 적는다.** 아무것도 안 한다는 말을 길게 쓰면 오히려 무언가
                    // 하는 것처럼 읽힌다. 자세한 것은 '이 앱이 쓰는 자료' 안에 있다.
                    //
                    // **줄은 뜻 단위로 손수 끊는다.** 흐르게 두면 폭에 따라 아무 데서나
                    // 갈려서, 한 문장이 두 조각으로 읽힌다.
                    Text("""
                        계정도 서버도 없습니다.
                        사전은 앱 안에 있고, 모은 낱말은 기기 안에만 있습니다.
                        """)
                        .font(Theme.korean(13))
                        .foregroundStyle(Theme.grey2)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, Self.topPadding)
                .padding(.bottom, Theme.screenBottom)
                .frame(maxWidth: Theme.readWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.paper)
            .koreanNavigationTitle("설정")
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    /// 모습 고르개.
    ///
    /// **고른 것 하나만 검게 채워진다** — 책장의 `묶음별 / 날짜별 / 모두`,
    /// 읽기 보조의 `가나 / 한자 / 한글`과 같은 문법이다.
    ///
    /// 다만 그 둘과 달리 **셋을 감싸는 면(트랙)을 깐다.** 그것들은 글 곁에 붙어 있어
    /// 눌러 보기 전에도 컨트롤로 읽히는데, 여기는 섹션 하나에 이것만 놓여 안 고른 둘이
    /// 바탕 위에 그냥 떠 있었다 — **누를 수 있는 것인지가 안 보였다.**
    /// 트랙이 "이 셋 중 하나를 고른다"를 말하고, 채워지는 것은 여전히 하나뿐이라
    /// 강조 규칙(반전 하나)은 그대로다.
    ///
    /// 굵기로는 가르지 않는다. 고운돋움은 굵기가 하나뿐이라 `weight` 를 줘도 듣지 않는다 —
    /// 위계는 채움과 색이 만든다.
    private var dial: some View {
        HStack(spacing: 4) {
            ForEach(Appearance.allCases) { option in
                let selected = option == appearance
                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        appearance = option
                        option.save(in: preferences)
                    }
                } label: {
                    Text(option.label)
                        .font(Theme.korean(14))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(selected ? Theme.ink : .clear, in: Capsule())
                        .foregroundStyle(selected ? Theme.paper : Theme.grey1)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Theme.grey4, in: Capsule())
        // 트랙이 글 폭을 다 먹지 않게 한다. 셋뿐인 고르개가 560 을 가로지르면
        // 컨트롤이 아니라 띠로 보인다.
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.blockGap) {
            VStack(alignment: .leading, spacing: Theme.lineGap) {
                Text(title)
                    .font(Theme.korean(12))
                    .tracking(0.6)
                    .foregroundStyle(Theme.grey2)
                Rectangle().fill(Theme.grey3).frame(height: 0.5)
            }
            content()
        }
    }

    private func row(_ title: String, detail: String, chevron: Bool = true) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(Theme.korean(16))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 12)
            Text(detail)
                .font(Theme.korean(13))
                .foregroundStyle(Theme.grey2)
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.grey3)
            }
        }
        .padding(.vertical, Self.rowPadding)
        .contentShape(Rectangle())
    }
}
