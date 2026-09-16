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
struct Onboarding: View {
    /// `--onboarding-page=2` 로 그 장을 펼친 채 띄운다. `--detail` · `--quiz` 와 같은
    /// 취지다 — 시뮬레이터는 손으로 밀 수 없어 뒷장을 눈으로 볼 길이 없다.
    @State private var page = LaunchOptions.current.int(for: "onboarding-page") ?? 0
    var onDone: () -> Void = {}

    /// 마지막 버튼이 차지할 자리. `다음` 과 `시작` 중 넓은 쪽에 맞춘다 —
    /// 장을 넘길 때 글자가 바뀌어도 자리가 흔들리지 않는다.
    private static var actionWidth: CGFloat {
        max(Theme.koreanWidth("다음", size: .body), Theme.koreanWidth("시작", size: .body))
    }

    private var pages: [OnboardingPage] { OnboardingPage.all }

    /// 탭바 지도. 짚으면 그 탭을 말하는 장으로 넘어간다.
    private var tabMap: some View {
        OnboardingTabMap(focusedTab: pages[page].tab) { tab in
            guard let target = pages.firstIndex(where: { $0.tab == tab }) else { return }
            withAnimation(.snappy(duration: 0.18)) { page = target }
        }
    }

    /// 글이 서는 자리의 높이. 제목 두 줄 + 설명 두 줄이 들어갈 만큼이다.
    ///
    /// **붙박아 두지 않으면 제목이 장마다 다른 높이에 선다.** 남는 자리를 다 차지하게
    /// 두면 글 덩어리가 그 안에서 가운데를 잡는데, 제목이 한 줄인 장과 두 줄인 장의
    /// 첫 줄이 그 차이의 절반만큼 어긋난다 — 위의 지도는 붙박이라 그 어긋남이 그대로
    /// 보인다. 빈 화면들의 `Theme.emptyBlockHeight` 와 같은 취지다.
    private static let textHeight: CGFloat = 150

    /// 한 장의 세로 뼈대 — 위 여백 · 지도 · 글 자리 · 아래 여백.
    ///
    /// **페이지 속과 붙박이 지도가 같은 뼈대를 쓴다.** 페이지는 여기 지도를 `hidden` 으로
    /// 넣어 자리만 비워 두고, 진짜 지도는 같은 뼈대로 그 위에 얹는다(`overlay`). 같은
    /// 것으로 재니 두 자리가 픽셀까지 맞고, 넘어가는 것은 글뿐이라는 규칙도 그대로다.
    ///
    /// **이 뼈대가 화면을 다 차지하는 것이 요점이다.** 예전에는 글 자리(150pt)만
    /// `TabView` 였고 위아래 여백은 그 밖이라, 손가락이 **글 위에 있을 때만** 넘어갔다.
    /// 이제 여백까지 한 장 안에 있어 빈 자리를 밀어도 넘어간다 — 글이 서는 높이는
    /// 그대로다(여백 둘이 남는 자리를 반씩 갈라 갖는 것이 예전과 같다).
    private func column<Map: View, Words: View>(
        @ViewBuilder map: () -> Map,
        @ViewBuilder words: () -> Words
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            map()
                // **왼쪽에서 시작한다.** 안 주면 줄이 제 폭만큼만 차지하고
                // 기둥 안에서 가운데로 밀려, 글만 왼쪽에 서고 지도는 가운데에 선다.
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.gutter)
                .frame(maxWidth: Theme.readWidth + Theme.gutter * 2)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 30)
            // **글이 설 자리를 붙박아 둔다.** 남는 자리를 다 차지하게 두면 제목이
            // 화면 가운데로 떠올라, 붙박이인 지도와 사이가 장마다 달라 보인다.
            // 가장 긴 덩어리(제목 두 줄 + 설명 두 줄)가 들어갈 만큼 잡는다.
            words()
                .frame(height: Self.textHeight)
            Spacer(minLength: 0)
        }
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
                //
                // **한 장이 점·버튼 줄 위를 통째로 차지한다.** 글 자리만 페이지였을 때는
                // 손가락이 글 위에 있을 때만 넘어갔다 — 화면의 대부분인 빈 자리는
                // 밀어도 아무 일도 안 일어났다.
                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { i in
                        column {
                            // **지도는 자리만 비워 둔다.** 진짜 지도는 아래 `overlay` 가
                            // 같은 뼈대로 그 위에 얹는다 — 넘어가는 것은 글뿐이다.
                            tabMap.hidden()
                        } words: {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(pages[i].title)
                                    .font(Theme.korean(.hero, weight: .semibold))
                                    .foregroundStyle(Theme.ink)
                                Text(pages[i].detail)
                                    .font(Theme.korean(.body))
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
                        }
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                // **지도는 붙박이다.** 넘어가는 것은 글뿐이라, 포커스가 자리에서
                // 자리로 옮겨 가는 것이 보인다. 페이지 속의 `hidden` 지도와 같은
                // 뼈대를 쓰므로 자리가 정확히 겹친다.
                .overlay {
                    column {
                        tabMap.animation(.snappy(duration: 0.22), value: page)
                    } words: {
                        // 글 자리는 빈 채로 둔다. **손을 안 받아야** 그 위를 밀 때
                        // 페이지가 넘어간다 — `Color.clear` 도 그냥 두면 손을 받는다.
                        Color.clear.allowsHitTesting(false)
                    }
                }

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
                    .font(Theme.korean(.body))
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
                    .font(Theme.korean(.body))
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
                        .font(Theme.korean(.sub))
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
