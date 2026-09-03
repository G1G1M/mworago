import SwiftUI

/// 처음 열었을 때 네 장.
///
/// 앱의 이야기를 순서대로 들려준다 — **찾고, 담기고, 다시 만난다.** 탭 셋의 관계를
/// 한 번에 말할 수 있는 것이 이 꼴뿐이라 이것으로 정했다. 대신 앱에 닿는 것이 그만큼
/// 늦어지므로 **건너뛰기를 늘 열어 둔다.**
///
/// 마지막 장은 이야기가 아니라 **지도**다. 탭바에서 글자를 빼고 아이콘만 남겼으므로
/// (넷뿐이고 뜻이 분명한 기호라는 판단이었다) 어느 자리가 무엇인지 한 번은 짚어야 한다.
/// 글자 탭과 설정은 이야기 안에 자리가 없어 여기서 함께 말한다 —
/// 그것 때문에 장을 둘 더 늘리면 앱에 닿는 것만 늦어진다.
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

    /// 마지막 버튼이 차지할 자리. `다음` 과 `시작` 중 넓은 쪽에 맞춘다 —
    /// 장을 넘길 때 글자가 바뀌어도 자리가 흔들리지 않는다.
    private static var actionWidth: CGFloat {
        max(Theme.koreanWidth("다음", size: 15), Theme.koreanWidth("시작", size: 15))
    }

    /// 탭바에 선 다섯 자리. 마지막 장이 이것을 짚는다.
    private static let tabs: [(symbol: String, name: String)] = [
        ("magnifyingglass", "찾기"),
        ("books.vertical", "책장"),
        ("rectangle.stack", "연습"),
        ("character.book.closed", "글자"),
        ("gearshape", "설정"),
    ]

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
            Page(sample: AnyView(
                // 탭바를 그대로 옮겨 그리지 않는다. **이름을 붙여 두는 것이 이 장의 일**이라
                // 아이콘 아래에 이름을 단다 — 진짜 탭바에는 없는 것이고, 그래서 여기 있다.
                HStack(alignment: .top, spacing: 22) {
                    ForEach(Self.tabs, id: \.name) { tab in
                        VStack(spacing: 8) {
                            Image(systemName: tab.symbol)
                                .font(.system(size: 22))
                                .foregroundStyle(Theme.ink)
                                .frame(height: 26)
                            Text(tab.name)
                                .font(Theme.korean(11))
                                .foregroundStyle(Theme.grey2)
                        }
                    }
                }),
                 title: "나머지는 아래에 있어요",
                 // 글자 탭이 여기 있는 까닭은 **막히는 자리가 정해져 있지 않아서**다.
                 // 가나를 못 읽어 멈추는 일은 찾을 때도 연습할 때도 생긴다.
                 detail: "가나를 못 읽어 멈추면 글자 탭으로 가요 — 오십음도 표와 익히기가 있습니다.\n설정에서는 밝기와 쓰는 자료를 봐요."),
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
                        // **기둥은 페이지 안에 있다.** 바깥에 두면 `TabView` 자체가
                        // 좁아져서, 넘길 때 그 폭의 경계에서 옆 페이지가 잘려 나타난다 —
                        // 미끄러지는 내내 세로선 하나가 서 있는 것처럼 보인다.
                        // 페이지는 화면 끝까지 흐르고, 글만 기둥 안에 선다.
                        .frame(maxWidth: Theme.readWidth + Theme.gutter * 2)
                        .frame(maxWidth: .infinity)
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

                    // **자리를 두 낱말 중 넓은 쪽에 맞춰 붙박고 오른쪽 끝에 맞춘다.**
                    //
                    // 이 버튼은 `Spacer` 뒤에 있어 오른쪽 끝이 붙박이다. 글자가 길어지면
                    // 왼쪽으로 자라므로, 마지막 장에서 낱말이 바뀔 때 시작 자리가 튄다.
                    // 그래서 자리를 미리 잡아 둔다 — 첫 장에서 `이전` 을 감추되 자리는
                    // 남기는 것과 같은 규칙이다.
                    //
                    // **오른쪽에 맞춘다.** 왼쪽에 붙이면 짧은 낱말일 때 남는 자리가
                    // 오른쪽에 생겨, 왼쪽 여백(점들)보다 오른쪽이 넓어 보였다. 두 낱말을
                    // `다음` · `시작` 으로 글자 수까지 맞춰 두면 남는 자리 자체가 거의 없다.
                    Button(page == pages.count - 1 ? "시작" : "다음") {
                        withAnimation(.snappy(duration: 0.18)) {
                            if page == pages.count - 1 { onDone() } else { page += 1 }
                        }
                    }
                    .font(Theme.korean(15))
                    .foregroundStyle(Theme.ink)
                    .buttonStyle(.plain)
                    .frame(width: Self.actionWidth, alignment: .trailing)
                }
                .padding(.horizontal, Theme.gutter)
                // 페이지와 **같은 기둥**이다. 둘 다 화면 폭 안에서 한 번씩 가운데를
                // 잡으므로 시작 자리가 맞는다.
                .frame(maxWidth: Theme.readWidth + Theme.gutter * 2)
                .frame(maxWidth: .infinity)
            }
            .padding(.bottom, 40)
            // **기둥을 바깥이 아니라 안쪽에 둔다.**
            //
            // 한때는 캐러셀과 점·버튼 줄을 통째로 한 기둥에 넣었다. 시작 자리는 맞았지만
            // `TabView` 자체가 그 폭으로 좁아져서, 넘길 때 기둥 경계에서 옆 페이지가
            // 잘려 나타났다 — 미끄러지는 내내 세로선 하나가 서 있는 것처럼 보였다.
            //
            // 페이지와 점·버튼 줄이 **각자 같은 기둥을 화면 폭 안에서** 잡는다.
            // 폭이 같고 가운데도 같으니 시작 자리는 그대로 맞고, `TabView` 는 화면
            // 끝까지 써서 미끄러지는 자리에 경계가 없다.

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
