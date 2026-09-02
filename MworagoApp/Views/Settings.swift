import SwiftUI

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
/// **`UserDefaults` 를 쓰지 않는다.** 그것은 사유를 밝혀야 하는 API 라, 쓰는 순간
/// 개인정보 보고서(`PrivacyInfo.xcprivacy`)에 사유를 적어야 한다. 아무것도 모으지
/// 않는다는 선언이 값 하나 때문에 길어질 이유가 없다 — 온보딩 "봤음" 표시와 같은
/// 까닭으로, 모은 낱말 파일 옆에 한 글자짜리 파일을 둔다.
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

    private static func path() -> String {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("appearance").path
    }

    static var saved: Appearance {
        guard let raw = try? String(contentsOfFile: path(), encoding: .utf8),
              let value = Appearance(rawValue: raw.trimmingCharacters(in: .whitespacesAndNewlines))
        else { return .system }
        return value
    }

    func save() { try? rawValue.write(toFile: Self.path(), atomically: true, encoding: .utf8) }
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

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Self.sectionGap) {
                    // 곁말("고르지 않으면 기기 설정을 따릅니다")을 뺐다. 고르개에
                    // `기기 따라`가 이미 적혀 있고 그것이 골라져 있으므로, 같은 말을
                    // 두 자리에서 하는 셈이었다.
                    section("모습") { dial }

                    section("앱에 대하여") {
                        VStack(alignment: .leading, spacing: 0) {
                            NavigationLink { Credits() } label: {
                                row("이 앱이 쓰는 자료", detail: "사전 · 글꼴 · 라이선스")
                            }
                            .buttonStyle(.plain)

                            Rectangle().fill(Theme.grey3).frame(height: 0.5)

                            row("버전", detail: version, chevron: false)
                        }
                    }

                    // 계정도 서버도 없는 앱이라 약관에 적을 것이 사실상 없다.
                    // 없는 것을 있는 척 적기보다, 무엇을 하지 않는지를 적는다.
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
                        option.save()
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
