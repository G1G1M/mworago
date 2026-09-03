import SwiftUI
import MworagoCore

/// 처음 열었을 때 다섯 장.
///
/// **탭 하나에 한 장씩이다.** 찾기 · 책장 · 연습 · 글자 · 설정 — 탭바에 선 차례
/// 그대로 넘어간다. 각 장은 그 탭에서 **실제로 보게 될 화면 조각**을 작게 그리고,
/// 무엇을 하는 곳인지 한 줄로 적는다. 앱에 닿는 것이 그만큼 늦어지므로
/// **건너뛰기를 늘 열어 둔다.**
///
/// 한때는 이야기 셋(찾고 · 담기고 · 다시 만난다)에 탭바 지도 한 장을 붙인 넷이었다.
/// 지도 장은 아이콘 다섯에 이름을 달아 주는 일을 했는데, 이야기 장들이 이미 앞의 세
/// 탭을 짚고 있어 **같은 말을 두 번** 하는 자리였다. 지도를 걷어내는 대신 그 일을
/// 다섯 장에 나눠 준다 — **각 장 맨 위에 그 탭의 아이콘과 이름이 선다.**
/// 탭바에는 글자가 없으므로(아이콘만 둔다) 이름을 말하는 자리는 여기뿐이다.
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
        /// 이 장이 가리키는 탭. 아이콘과 이름이 장 맨 위에 조용히 선다.
        ///
        /// **탭바에는 글자가 없다**(아이콘만 둔다). 그래서 어느 자리가 무엇인지
        /// 말하는 곳은 여기뿐이고, 한때 마지막 장에 몰아 두었던 그 일을
        /// 다섯 장이 나눠 맡는다.
        let tab: (symbol: String, name: String)
        /// 그 탭에서 실제로 보게 될 화면 조각. 심볼 하나를 세우던 자리다 —
        /// 무엇을 하는 곳인지는 그림보다 화면이 더 빨리 말한다.
        let sample: AnyView
        /// 그림이 글보다 **안쪽에서** 시작하는 만큼(pt). 그만큼 왼쪽으로 당겨 세운다.
        ///
        /// 같은 `.leading` 에 두어도 가나는 글자보다 오른쪽에서 시작한 것처럼 보인다 —
        /// 글리프 안에 제 여백을 갖고 있기 때문이다. 그래서 장을 넘길 때
        /// 제목·본문은 가만히 있는데 그림만 좌우로 흔들렸다.
        ///
        /// **둥근 네모나 알약으로 시작하는 조각은 0 이다** — 도형은 제 여백을 안고
        /// 있지 않아 그린 자리에서 그대로 시작한다. 값이 필요한 것은 글자로 시작하는
        /// 조각뿐이고, 그때는 **스크린샷 픽셀로 재서** 넣는다(2배 화면에서 잰 값의
        /// 절반이 pt 다). 글자나 크기를 바꾸면 다시 재야 한다.
        var opticalLeading: CGFloat = 0
        let title: String
        let detail: String
    }

    private var pages: [Page] {
        [
            // ① 찾기 — 친 것과 나온 것.
            //
            // **입력 바를 위에 둔다.** 진짜 화면에서는 바가 바닥이고 결과가 그 위에
            // 뜨는데, 이 장이 하는 말은 "치면 나온다"라서 읽는 차례(위 → 아래)가
            // 곧 일의 차례여야 한다. 자리를 옮겨 그린 곳은 여기 한 군데다.
            Page(tab: Self.tabs[0],
                 sample: AnyView(
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(Theme.korean(15))
                                .foregroundStyle(Theme.grey2)
                            Text("아타마가이타이")
                                .font(Theme.korean(15))
                                .foregroundStyle(Theme.ink)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        // 진짜 입력 바와 같은 재료다 — 유리와 0.5pt 테두리.
                        // 떠 있는 컨트롤에만 쓰는 것이라 다른 조각에는 없다.
                        .background(.ultraThinMaterial,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Theme.grey3.opacity(0.5), lineWidth: 0.5))

                        Text("頭が痛い")
                            .font(Theme.japanese(26, weight: .medium))
                            .foregroundStyle(Theme.ink)
                            // 한자는 둥근 네모보다 1pt 안쪽에서 시작한다. 이 줄만 더 당긴다.
                            .padding(.leading, -1)
                    }),
                 opticalLeading: -1.7,   // 둥근 네모는 제 여백이 없어 글보다 밖에서 선다
                 // **무엇을 치라는 것인지 첫 줄에 적는다.** "들린 대로 치세요"는 이 앱이
                 // 무엇을 하는 물건인지 이미 아는 사람에게만 통했다 — 처음 온 사람은
                 // 무엇을 들었다는 것인지부터 막힌다. 빠진 낱말은 **일본어**다.
                 title: "일본어를 들리는 대로 쳐보세요",
                 detail: "띄어 쓰지 않아도 됩니다.\n어디서 끊을지는 사전이 정해요."),

            // ② 책장 — 묶음이 서는 줄.
            Page(tab: Self.tabs[1],
                 sample: AnyView(
                    VStack(alignment: .leading, spacing: 0) {
                        Self.shelfRow(name: "1화", count: "3", preview: "あたま · いたい")
                        Rectangle()
                            .fill(Theme.grey3.opacity(0.35))
                            .frame(height: 0.5)
                        Self.shelfRow(name: "2화", count: "5", preview: "だいじょうぶ")
                    }
                    // 폭을 묶어 두지 않으면 줄 안의 `Spacer` 가 기둥 끝까지 벌어져,
                    // 조각이 아니라 진짜 목록처럼 화면을 가로지른다.
                    .frame(width: 268)),
                 opticalLeading: -1.3,
                 title: "담으면 교재가 됩니다",
                 // 전에는 "한 화를 보며 찾은 것들은 같은 날 모이니 날짜가 곧 그 화"였다.
                 // **두 번 낡은 말이다.** 날짜는 어느 화를 봤는지 앱이 몰라서 쓰던
                 // 대용품인데 이제 담을 때 묶음을 직접 고르고, 애초에 영상을 안 보고
                 // 온 사람에게 "한 화"는 없는 말이다.
                 detail: "갈피표를 누르면 어디에 넣을지 물어봐요.\n묶음은 마음대로 만들고 옮길 수 있습니다."),

            // ③ 연습 — 카드의 앞면. 뒤에 있는 것은 흐리게 둔다.
            Page(tab: Self.tabs[2],
                 sample: AnyView(
                    VStack(alignment: .leading, spacing: 10) {
                        Text("いたい")
                            .font(Theme.japanese(34, weight: .medium))
                            .foregroundStyle(Theme.ink)
                        // **뒤집어야 나오는 것이라 흐리다.** 앞면에 또렷이 적으면
                        // 이 장이 말하려는 "떠올린 다음 뒤집는다"가 거짓이 된다.
                        VStack(alignment: .leading, spacing: 5) {
                            Text("이타이")
                                .font(Theme.korean(13))
                                .foregroundStyle(Theme.grey3)
                            Text("아프다")
                                .font(Theme.korean(15))
                                .foregroundStyle(Theme.grey1)
                        }
                        .opacity(0.3)
                    }),
                 opticalLeading: 1,
                 title: "다시 만나요",
                 // 앞면이 한글에서 **가나**로 바뀌었다 — 한글 음차는 찾을 때 쓰는
                 // 열쇠지 익힐 것이 아니고, 자막에 뜨는 것은 `いたい` 이지 `이타이` 가 아니다.
                 detail: "가나를 보고 뜻을 떠올린 다음 뒤집어 맞춰 봐요.\n채점하지 않아요."),

            // ④ 글자 — 오십음도의 첫 두 줄.
            Page(tab: Self.tabs[3],
                 sample: AnyView(
                    VStack(alignment: .leading, spacing: 12) {
                        Self.kanaRow(["あ", "い", "う"])
                        Self.kanaRow(["か", "き", "く"])
                    }),
                 opticalLeading: 1,
                 title: "가나를 못 읽어도 괜찮아요",
                 // 글자 탭이 따로 있는 까닭은 **막히는 자리가 정해져 있지 않아서**다.
                 // 가나를 못 읽어 멈추는 일은 찾을 때도 연습할 때도 생기는데,
                 // 한때 연습 안의 쪽지로만 두었더니 연습 화면에서만 닿았다.
                 detail: "오십음도 표가 있고, 한 글자씩 뒤집어 익힐 수도 있어요.\n찾다가 막혀도 연습하다 막혀도 같은 자리예요."),

            // ⑤ 설정 — 모습을 고르는 다이얼.
            Page(tab: Self.tabs[4],
                 sample: AnyView(
                    HStack(spacing: 6) {
                        Self.appearancePill("기기 따라", on: true)
                        Self.appearancePill("밝게", on: false)
                        Self.appearancePill("어둡게", on: false)
                    }),
                 opticalLeading: -1.3,
                 title: "눈이 편한 쪽으로 보세요",
                 // 설정은 앱의 이야기(찾고·담기고·다시 만난다) 밖이지만 어느 화면에서나
                 // 닿아야 하는 자리라 탭으로 두었다. 여기서도 한 번 짚는다.
                 detail: "밝게 볼지 어둡게 볼지 고를 수 있어요.\n이 앱이 어떤 사전을 쓰는지도 여기서 봐요."),
        ]
    }

    /// 책장의 묶음 한 줄. 진짜 줄에서 크기만 줄였다.
    private static func shelfRow(name: String, count: String, preview: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(name)
                .font(Theme.korean(15, weight: .medium))
                .foregroundStyle(Theme.ink)
            Text(count)
                .font(Theme.korean(12))
                .foregroundStyle(Theme.grey3)
            Spacer(minLength: 10)
            Text(preview)
                .font(Theme.japanese(12))
                .foregroundStyle(Theme.grey3)
                .lineLimit(1)
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.grey3)
        }
        .padding(.vertical, 11)
    }

    /// 오십음도 한 줄. 가나 아래 한글은 표에서 하는 그대로 사전에서 가져온다 —
    /// 여기에 손으로 적어 두면 표와 갈라진다.
    private static func kanaRow(_ kana: [String]) -> some View {
        HStack(spacing: 20) {
            ForEach(kana, id: \.self) { one in
                VStack(spacing: 3) {
                    Text(one)
                        .font(Theme.japanese(22))
                        .foregroundStyle(Theme.ink)
                    Text(KanaToHangul.transliterate(one))
                        .font(Theme.korean(11))
                        .foregroundStyle(Theme.grey3)
                }
            }
        }
    }

    /// 설정의 `모습` 알약 하나. 강조는 반전 하나로만 — 앱 전체와 같은 규칙이다.
    private static func appearancePill(_ label: String, on: Bool) -> some View {
        Text(label)
            .font(Theme.korean(13))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(on ? Theme.ink : .clear, in: Capsule())
            .foregroundStyle(on ? Theme.paper : Theme.grey1)
    }

    /// 장 맨 위에 서는 탭 표시 — 아이콘과 이름.
    ///
    /// **조용해야 한다.** 이 줄이 하는 일은 "지금 말하는 곳이 저 자리다"를 잇는 것이지
    /// 제목 노릇이 아니다. 그래서 회색으로, 본문보다 작게 둔다.
    private func tabMark(_ tab: (symbol: String, name: String)) -> some View {
        HStack(spacing: 7) {
            Image(systemName: tab.symbol)
                .font(.system(size: 13))
            Text(tab.name)
                .font(Theme.korean(13))
        }
        .foregroundStyle(Theme.grey2)
        // 심볼도 글리프 안에 제 여백을 안고 있다. 다섯 장이 같은 줄을 쓰므로 값도 하나다.
        .padding(.leading, -Self.tabMarkLeading)
    }

    /// 탭 표시가 글보다 안쪽에서 시작하는 만큼(pt). 스크린샷을 픽셀로 재서 넣는다.
    ///
    /// **재 보니 0 이면 된다** — 돋보기·책·카드·책자·톱니가 다섯 장에서 25.0~25.7pt 에
    /// 섰고, 제목이 25.3~26.7pt 라 이미 같은 자리다. 심볼 크기(13pt)가 작아 글리프가
    /// 안고 있는 여백도 그만큼 작다. 크기를 키우면 다시 재야 한다.
    private static let tabMarkLeading: CGFloat = 0

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
                                // 탭 표시와 화면 조각은 **한 덩어리**다 — 저 자리에서
                                // 이런 것을 본다는 한 문장이라 사이를 좁게 둔다.
                                VStack(alignment: .leading, spacing: 14) {
                                    tabMark(pages[i].tab)
                                    pages[i].sample
                                        // 조각마다 높이가 다른데 자리를 고정하지 않으면
                                        // 장을 넘길 때 아래의 제목이 위아래로 뛴다.
                                        //
                                        // **위에 붙인다.** 가운데 두면 키 작은 조각
                                        // (설정의 알약 하나)만 탭 표시에서 멀리 떨어져,
                                        // 한 덩어리로 읽혀야 할 둘이 갈라져 보인다.
                                        // 남는 자리는 아래에 둔다.
                                        .frame(height: 104, alignment: .topLeading)
                                        // 그림만 글보다 안쪽에서 시작하던 것을 당겨 세운다 —
                                        // 까닭은 `Page.opticalLeading` 에 적어 두었다.
                                        .padding(.leading, -pages[i].opticalLeading)
                                }

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
