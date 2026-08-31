import SwiftUI

/// 처음 열었을 때 세 장.
///
/// 앱의 이야기를 순서대로 들려준다 — **찾고, 담기고, 다시 만난다.** 탭 셋의 관계를
/// 한 번에 말할 수 있는 것이 이 꼴뿐이라 이것으로 정했다. 대신 앱에 닿는 것이 세 번
/// 늦어지므로 **건너뛰기를 늘 열어 둔다.**
///
/// 시안 넷을 만들어 견줬다(페이지형·포커스형·한 장·첫 성공 뒤). 포커스형은 진짜 입력
/// 바 자리에 구멍을 뚫어야 해서 복제본이 생겼고, 첫 성공 뒤에 한 번 짚는 안은 조용하지만
/// 탭 셋의 관계를 말하지 못했다.

/// 온보딩을 봤는지.
///
/// **`UserDefaults` 를 쓰지 않는다.** 그것은 사유를 밝혀야 하는 API 라, 쓰는 순간
/// 개인정보 보고서(`PrivacyInfo.xcprivacy`)에 사유를 적어야 한다. 아무것도 모으지
/// 않는다는 선언이 그만큼 길어지는데, 값 하나 때문에 치를 값은 아니다.
/// 모은 낱말 파일 옆에 빈 파일 하나를 둔다 — 있으면 본 것이다.
enum OnboardingSeen {
    static func path() -> String {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("onboarding-seen").path
    }

    static var already: Bool { FileManager.default.fileExists(atPath: path()) }

    static func mark() { FileManager.default.createFile(atPath: path(), contents: nil) }

    /// `--onboarding` 으로 언제든 다시 띄운다. 봤는지와 무관하게 화면을 확인하려는 것이다.
    static var forced: Bool { ProcessInfo.processInfo.arguments.contains("--onboarding") }
}

struct Onboarding: View {
    @State private var page = 0
    var onDone: () -> Void = {}

    private struct Page {
        let sample: AnyView
        let title: String
        let detail: String
    }

    private var pages: [Page] {
        [
            Page(sample: AnyView(
                VStack(alignment: .leading, spacing: 10) {
                    Text("아타마가이타이")
                        .font(Theme.korean(20))
                        .foregroundStyle(Theme.grey2)
                    Text("頭が痛い")
                        .font(Theme.japanese(40, weight: .medium))
                        .foregroundStyle(Theme.ink)
                }),
                 title: "들린 대로 치세요",
                 detail: "띄어 쓰지 않아도 됩니다.\n어디서 끊을지는 사전이 정해요."),
            Page(sample: AnyView(
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(Theme.ink)),
                 title: "담으면 교재가 됩니다",
                 detail: "한 화를 보며 찾은 것들은 같은 날 모이니,\n날짜가 곧 그 화가 돼요."),
            Page(sample: AnyView(
                Image(systemName: "waveform")
                    .font(.system(size: 38))
                    .foregroundStyle(Theme.ink)),
                 title: "다시 만나요",
                 detail: "한글만 보고 떠올린 다음 뒤집어 확인합니다.\n채점하지 않아요."),
        ]
    }

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 26) {
                    pages[page].sample
                        .frame(height: 96, alignment: .leading)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(pages[page].title)
                            .font(Theme.korean(26, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(pages[page].detail)
                            .font(Theme.korean(15))
                            .foregroundStyle(Theme.grey2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: 460, alignment: .leading)

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { i in
                        Circle()
                            .fill(i == page ? Theme.ink : Theme.grey3)
                            .frame(width: 6, height: 6)
                    }
                    Spacer()
                    Button(page == pages.count - 1 ? "시작하기" : "다음") {
                        withAnimation(.snappy(duration: 0.18)) {
                            if page == pages.count - 1 { onDone() } else { page += 1 }
                        }
                    }
                    .font(Theme.korean(15))
                    .foregroundStyle(Theme.ink)
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: 460)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity)

            VStack {
                HStack {
                    Spacer()
                    Button("건너뛰기", action: onDone)
                        .font(Theme.korean(14))
                        .foregroundStyle(Theme.grey2)
                        .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
        }
    }
}
