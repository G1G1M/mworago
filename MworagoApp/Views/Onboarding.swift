import SwiftUI
import MworagoCore

/// 처음 열었을 때 다섯 장.
///
/// **탭 하나에 한 장씩이다.** 찾기 · 책장 · 연습 · 글자 · 설정 — 탭바에 선 차례
/// 그대로 넘어간다.
///
/// 화면 위에 **탭바 지도가 늘 서 있고, 포커스만 옮겨 다닌다.** 첫 장부터 다섯 자리가
/// 전부 보이고(어디에 무엇이 있는지 한눈에 들어온다), 장을 넘길 때마다 지금 말하는
/// 자리가 검게 채워진다. 탭바에는 글자가 없으므로(아이콘만 둔다) 이름을 말하는 곳은
/// 여기뿐이라, 다섯 이름을 처음부터 함께 보인다.
///
/// **지도는 넘어가는 글 바깥에 둔다.** 장마다 제 지도를 그리면 포커스가 옮겨 가는 것이
/// 아니라 지도째로 미끄러진다 — 그러면 "저 자리가 이 자리로 옮겨 갔다"는 말이 안 된다.
/// 지도는 붙박이고 글만 넘어간다.
///
/// 한때는 각 장에 그 탭의 화면 조각(입력 바 · 묶음 줄 · 카드 앞면)을 그렸다. 무엇을
/// 하는 곳인지는 잘 말했지만 **조각마다 생김새가 달라 장을 넘길 때 눈이 매번 다시
/// 적응해야 했고**, 탭바와 이어 주는 일은 못 했다. 지도 하나로 되돌린다.
///
/// 시안 넷을 만들어 견줬다(페이지형·포커스형·한 장·첫 성공 뒤). 포커스형은 진짜 입력
/// 바 자리에 구멍을 뚫어야 해서 복제본이 생겼고, 첫 성공 뒤에 한 번 짚는 안은 조용하지만
/// 탭 셋의 관계를 말하지 못했다.

/// 온보딩을 봤는지.
///
/// **적어 두는 일은 밖에서 한다**(`PreferenceStoring`). 예전에는 이 enum 이 직접
/// Application Support 를 찾아 빈 파일을 만들었다 — 뷰 파일 안에 파일 IO 가
/// 박혀 있었고, 같은 여섯 줄이 모습 설정과 모은 낱말 자리에도 복붙되어 있었다.
///
/// **값이 아니라 표시다.** 오래도록 빈 파일이었으므로 그 파일이 있으면 본 것으로
/// 친다 — 값으로 읽으면 이미 본 사람에게 온보딩이 다시 뜬다.
enum OnboardingSeen {
    /// 적어 둘 때 쓰는 이름. 예전에 남긴 빈 파일과 같은 이름이라 그대로 이어진다.
    static let key = "onboarding-seen"

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
        /// 이 장이 가리키는 탭. 지도에서 이 자리가 검게 채워진다.
        let tab: Int
        let title: String
        let detail: String
    }

    private var pages: [Page] {
        [
            Page(tab: 0,
                 // **무엇을 치라는 것인지 첫 줄에 적는다.** "들린 대로 치세요"는 이 앱이
                 // 무엇을 하는 물건인지 이미 아는 사람에게만 통했다 — 처음 온 사람은
                 // 무엇을 들었다는 것인지부터 막힌다. 빠진 낱말은 **일본어**다.
                 title: "일본어를 들리는 대로 쳐보세요",
                 detail: "띄어 쓰지 않아도 됩니다.\n어디서 끊을지는 사전이 정해요."),
            Page(tab: 1,
                 title: "담으면 교재가 됩니다",
                 // 전에는 "한 화를 보며 찾은 것들은 같은 날 모이니 날짜가 곧 그 화"였다.
                 // **두 번 낡은 말이다.** 날짜는 어느 화를 봤는지 앱이 몰라서 쓰던
                 // 대용품인데 이제 담을 때 묶음을 직접 고르고, 애초에 영상을 안 보고
                 // 온 사람에게 "한 화"는 없는 말이다.
                 detail: "갈피표를 누르면 어디에 넣을지 물어봐요.\n묶음은 마음대로 만들고 옮길 수 있습니다."),
            Page(tab: 2,
                 title: "다시 만나요",
                 // 앞면이 한글에서 **가나**로 바뀌었다 — 한글 음차는 찾을 때 쓰는
                 // 열쇠지 익힐 것이 아니고, 자막에 뜨는 것은 `いたい` 이지 `이타이` 가 아니다.
                 detail: "가나를 보고 뜻을 떠올린 다음 뒤집어 맞춰 봐요.\n채점하지 않아요."),
            Page(tab: 3,
                 title: "가나를 못 읽어도 괜찮아요",
                 // 글자 탭이 따로 있는 까닭은 **막히는 자리가 정해져 있지 않아서**다.
                 // 가나를 못 읽어 멈추는 일은 찾을 때도 연습할 때도 생기는데,
                 // 한때 연습 안의 쪽지로만 두었더니 연습 화면에서만 닿았다.
                 detail: "오십음도 표가 있고, 한 글자씩 뒤집어 익힐 수도 있어요.\n찾다가 막혀도 연습하다 막혀도 같은 자리예요."),
            Page(tab: 4,
                 title: "눈이 편한 쪽으로 보세요",
                 // 설정은 앱의 이야기(찾고·담기고·다시 만난다) 밖이지만 어느 화면에서나
                 // 닿아야 하는 자리라 탭으로 두었다. 여기서도 한 번 짚는다.
                 detail: "밝게 볼지 어둡게 볼지 고를 수 있어요.\n이 앱이 어떤 사전을 쓰는지도 여기서 봐요."),
        ]
    }

    /// 탭바 지도. 다섯 자리가 늘 서 있고 **지금 장의 것만 검게 채워진다.**
    ///
    /// 강조는 반전 하나로만 한다 — 채워진 것이 지금 말하는 자리다. 앱의 다른 곳
    /// (설정의 `모습`, 책장의 보기 다이얼, 탭바의 고른 칸)이 다 같은 문법을 쓴다.
    ///
    /// **아이콘 크기는 바뀌지 않는다.** 포커스를 크기로도 말하면 장을 넘길 때마다
    /// 줄의 높이가 흔들려, 아래 글이 위아래로 뛴다. 채우는 것 하나로 충분하다.
    private var tabMap: some View {
        HStack(alignment: .top, spacing: 18) {
            ForEach(Self.tabs.indices, id: \.self) { i in
                let focused = i == pages[page].tab
                VStack(spacing: 9) {
                    Image(systemName: Self.tabs[i].symbol)
                        .font(.system(size: 21))
                        .foregroundStyle(focused ? Theme.paper : Theme.grey3)
                        .frame(width: 46, height: 36)
                        .background(focused ? Theme.ink : .clear, in: Capsule())
                    Text(Self.tabs[i].name)
                        .font(Theme.korean(11))
                        .foregroundStyle(focused ? Theme.ink : Theme.grey3)
                }
            }
        }
        // 알약은 도형이라 제 여백이 없어 글보다 밖에서 선다. 스크린샷을 픽셀로 재서 당긴다.
        .padding(.leading, -Self.mapLeading)
    }

    /// 지도가 글보다 밖에서 시작하는 만큼(pt). 음수라 안쪽으로 민다.
    ///
    /// 알약은 도형이라 글리프가 안고 있는 여백이 없어, 기둥에 정확히 붙어 선다(24.0pt).
    /// 제목은 글자라 제 여백만큼 안에서 시작한다(25.7pt). 그 차이를 재서 넣는다 —
    /// 아이콘이나 알약 크기를 바꾸면 다시 재야 한다.
    private static let mapLeading: CGFloat = -1.7

    /// 글이 서는 자리의 높이. 제목 두 줄 + 설명 두 줄이 들어갈 만큼이다.
    ///
    /// **붙박아 두지 않으면 제목이 장마다 다른 높이에 선다.** 남는 자리를 다 차지하게
    /// 두면 글 덩어리가 그 안에서 가운데를 잡는데, 제목이 한 줄인 장과 두 줄인 장의
    /// 첫 줄이 그 차이의 절반만큼 어긋난다 — 위의 지도는 붙박이라 그 어긋남이 그대로
    /// 보인다. 빈 화면들의 `Theme.emptyBlockHeight` 와 같은 취지다.
    private static let textHeight: CGFloat = 150

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
                Spacer(minLength: 0)

                // **지도는 붙박이다.** 넘어가는 것은 글뿐이라, 포커스가 자리에서
                // 자리로 옮겨 가는 것이 보인다.
                tabMap
                    // **왼쪽에서 시작한다.** 안 주면 줄이 제 폭만큼만 차지하고
                    // 기둥 안에서 가운데로 밀려, 글만 왼쪽에 서고 지도는 가운데에 선다.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.gutter)
                    .frame(maxWidth: Theme.readWidth + Theme.gutter * 2)
                    .frame(maxWidth: .infinity)
                    .animation(.snappy(duration: 0.22), value: page)
                    .padding(.bottom, 30)

                // **넘기는 일은 시스템에 맡긴다.** 손가락으로 미는 것은 이 화면에서
                // 가장 먼저 해 보는 몸짓인데, 직접 만들면 속도·되돌아옴·경계에서
                // 멈추는 것까지 다시 만들어야 한다.
                //
                // 점은 우리 것을 쓴다(`indexDisplayMode: .never`). 시스템 점은 색을
                // 맞추기 번거롭고, 아래 줄에 이미 자리를 잡고 있다.
                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(pages[i].title)
                                .font(Theme.korean(26, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Text(pages[i].detail)
                                .font(Theme.korean(15))
                                .foregroundStyle(Theme.grey2)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        // 폭은 여기서 재지 않는다. 바깥 기둥이 이미 정해 준다 —
                        // 페이지 안에서 다시 가운데를 잡으면 아래 점·버튼 줄과 어긋난다.
                        .frame(maxWidth: .infinity, alignment: .leading)
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
                // **글이 설 자리를 붙박아 둔다.** 남는 자리를 다 차지하게 두면 제목이
                // 화면 가운데로 떠올라, 붙박이인 지도와 사이가 장마다 달라 보인다.
                // 가장 긴 덩어리(제목 두 줄 + 설명 두 줄)가 들어갈 만큼 잡는다.
                .frame(height: Self.textHeight)

                Spacer(minLength: 0)

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
