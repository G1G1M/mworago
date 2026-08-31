import SwiftUI

/// 화면을 밝게 볼지 어둡게 볼지.
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
    @Environment(\.dismiss) private var dismiss
    @Binding var appearance: Appearance

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    section("화면") {
                        VStack(alignment: .leading, spacing: 9) {
                            dial
                            Text("고르지 않으면 기기 설정을 따릅니다.")
                                .font(Theme.korean(13))
                                .foregroundStyle(Theme.grey2)
                        }
                    }

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
                    Text("""
                        계정이 없고 서버로 보내는 것도 없습니다. \
                        사전이 앱 안에 통째로 들어 있어 찾을 때 인터넷을 쓰지 않고, \
                        모은 낱말은 기기 안에만 있습니다.
                        """)
                        .font(Theme.korean(13))
                        .foregroundStyle(Theme.grey2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
                .padding(.top, 6)
                .padding(.bottom, 36)
                .frame(maxWidth: 520, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.paper)
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                        .font(Theme.korean(16))
                        .foregroundStyle(Theme.ink)
                }
            }
        }
    }

    /// 읽기 보조 다이얼과 같은 문법 — 평평하고, 고른 것 하나만 검게 채워진다.
    private var dial: some View {
        HStack(spacing: 6) {
            ForEach(Appearance.allCases) { option in
                let selected = option == appearance
                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        appearance = option
                        option.save()
                    }
                } label: {
                    Text(option.label)
                        .font(Theme.korean(13, weight: selected ? .semibold : .regular))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(selected ? Theme.ink : .clear, in: Capsule())
                        .foregroundStyle(selected ? Theme.paper : Theme.grey2)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
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
                .font(Theme.korean(15))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 12)
            Text(detail)
                .font(Theme.korean(13))
                .foregroundStyle(Theme.grey2)
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.grey3)
            }
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}
