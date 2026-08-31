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
    /// `--onboarding-page=2` 로 그 장을 펼친 채 띄운다. `--detail` · `--quiz` 와 같은
    /// 취지다 — 시뮬레이터는 손으로 밀 수 없어 뒷장을 눈으로 볼 길이 없다.
    @State private var page = ProcessInfo.processInfo.arguments
        .first { $0.hasPrefix("--onboarding-page=") }
        .flatMap { Int($0.dropFirst("--onboarding-page=".count)) } ?? 0
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
                 // 전에는 "한 화를 보며 찾은 것들은 같은 날 모이니 날짜가 곧 그 화"였다.
                 // **두 번 낡은 말이다.** 날짜는 어느 화를 봤는지 앱이 몰라서 쓰던
                 // 대용품인데 이제 담을 때 묶음을 직접 고르고, 애초에 영상을 안 보고
                 // 온 사람에게 "한 화"는 없는 말이다.
                 detail: "갈피표를 누르면 어디에 넣을지 물어봐요.\n묶음은 마음대로 만들고 옮길 수 있습니다."),
            Page(sample: AnyView(
                Image(systemName: "waveform")
                    .font(.system(size: 38))
                    .foregroundStyle(Theme.ink)),
                 title: "다시 만나요",
                 // 앞면이 한글에서 **가나**로 바뀌었다 — 한글 음차는 찾을 때 쓰는
                 // 열쇠지 익힐 것이 아니고, 자막에 뜨는 것은 `いたい` 이지 `이타이` 가 아니다.
                 detail: "가나를 보고 뜻을 떠올린 다음 뒤집어 맞춰 봐요.\n채점하지 않아요."),
        ]
    }

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // **넘기는 일은 시스템에 맡긴다.** 손가락으로 미는 것은 이 화면에서
                // 가장 먼저 해 보는 몸짓인데, 직접 만들면 속도·되돌아옴·경계에서
                // 멈추는 것까지 다시 만들어야 한다.
                //
                // 점은 우리 것을 쓴다(`indexDisplayMode: .never`). 시스템 점은 색을
                // 맞추기 번거롭고, 아래 줄에 이미 자리를 잡고 있다.
                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 0) {
                            Spacer(minLength: 0)
                            VStack(alignment: .leading, spacing: 26) {
                                pages[i].sample
                                    .frame(height: 96, alignment: .leading)

                                VStack(alignment: .leading, spacing: 12) {
                                    Text(pages[i].title)
                                        .font(Theme.korean(26, weight: .semibold))
                                        .foregroundStyle(Theme.ink)
                                    Text(pages[i].detail)
                                        .font(Theme.korean(15))
                                        .foregroundStyle(Theme.grey2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            // 폭은 여기서 재지 않는다. 바깥 기둥이 이미 정해 준다 —
                            // 페이지 안에서 다시 가운데를 잡으면 아래 점·버튼 줄과 어긋난다.
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, Theme.gutter)
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { i in
                        Circle()
                            .fill(i == page ? Theme.ink : Theme.grey3)
                            .frame(width: 6, height: 6)
                    }
                    Spacer()

                    // **첫 장에서도 자리는 남긴다.** 통째로 빼면 `다음` 이 좌우로
                    // 움직여, 같은 곳을 누르려는 손이 장마다 다시 겨눈다.
                    Button("이전") {
                        withAnimation(.snappy(duration: 0.18)) { page -= 1 }
                    }
                    .font(Theme.korean(15))
                    .foregroundStyle(Theme.grey2)
                    .buttonStyle(.plain)
                    .opacity(page == 0 ? 0 : 1)
                    .disabled(page == 0)
                    .accessibilityHidden(page == 0)
                    .padding(.trailing, 18)

                    // **자리를 가장 긴 글자에 맞춰 잡아 두고 왼쪽에 붙인다.**
                    //
                    // 이 버튼은 `Spacer` 뒤에 있어 오른쪽 끝이 붙박이다. 그래서 글자가
                    // 길어지면 왼쪽으로 자라, 마지막 장에서 `다음` 이 `시작하기` 로 바뀔 때
                    // 글자가 시작하는 자리가 왼쪽으로 튀었다.
                    //
                    // 눈은 자리로 읽는다 — 카드에서 한자 줄이 없어도 자리를 비워 두고,
                    // 첫 장에서 `이전` 을 감추되 자리는 남기는 것과 같은 규칙이다.
                    // `이전` 의 자리도 이것이 고정되어야 함께 안정된다.
                    Button(page == pages.count - 1 ? "시작하기" : "다음") {
                        withAnimation(.snappy(duration: 0.18)) {
                            if page == pages.count - 1 { onDone() } else { page += 1 }
                        }
                    }
                    .font(Theme.korean(15))
                    .foregroundStyle(Theme.ink)
                    .buttonStyle(.plain)
                    .frame(width: Theme.koreanWidth("시작하기", size: 15), alignment: .leading)
                }
                .padding(.horizontal, Theme.gutter)
            }
            .padding(.bottom, 40)
            // **캐러셀과 점·버튼 줄을 한 기둥에 넣고 한 번만 가운데로 세운다.**
            //
            // 전에는 둘이 각자 폭을 재고 각자 가운데를 잡았는데, `TabView` 는 아이패드에서
            // 페이지에 화면보다 좁은 폭을 준다. 그래서 페이지 안에서 잡은 가운데가 바깥과
            // 어긋났다 — 실측으로 점은 137pt, 글은 169pt 였다.
            //
            // 기둥 폭은 글 폭에 좌우 여백을 더한 것이다. 안에서는 둘 다 `Theme.gutter`
            // 하나만 쓰므로, 무엇이 어디서 시작하는지가 한자리에서 정해진다.
            .frame(maxWidth: Theme.readWidth + Theme.gutter * 2)
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
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 14)
        }
    }
}
