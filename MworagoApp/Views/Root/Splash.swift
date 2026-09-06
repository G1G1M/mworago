import SwiftUI

/// 앱을 여는 짧은 한 장.
///
/// 아이콘의 알약 셋이 통통 튀어 들어오고, 그중 **가운데 가장 긴 것이 검색 입력 바로**
/// 바뀌며 찾기 화면으로 넘어간다.
///
/// **장식이 아니라 문이다.** 아이콘의 알약은 붙여 친 한 줄을 사전이 낱말로 끊어 주는
/// 것을 그린 것이고(頭 · が · 痛い 의 비율), 찾기 화면의 입력 바는 그 한 줄을 받는
/// 자리다. 둘이 같은 도형이라, 하나가 다른 하나로 바뀌는 것이 곧 이 앱이 하는 일이다.
///
/// **규칙을 늘리지 않는다.** 흰검 두 색과 앱이 이미 쓰는 스프링 하나로만 만든다 —
/// 스플래시라고 새 문법을 들이면 첫 화면부터 앱과 딴 몸이 된다.
///
/// **1초 안에 끝나고 아무 데나 누르면 건너뛴다.** 매번 앱을 열 때마다 보는 것이라,
/// 처음엔 예뻐도 열 번째부터는 기다림이다. 모션을 줄이기로 한 기기에서는 아예 안 뛴다.
struct Splash: View {
    /// 진짜 입력 바가 놓인 자리(화면 좌표). 마지막 알약이 여기로 와서 앉는다.
    ///
    /// **재지 않고 묻는다.** 전에는 높이 52 · 아래 여백 70 을 들고 있었는데, 둘 다
    /// 시뮬레이터 하나에서 눈으로 잰 값이었다. 폰트가 조금 다르게 그려지거나 탭바
    /// 높이가 다른 기기·방향으로 가면 마지막 한 프레임에서 툭 튄다 —
    /// 이 장면의 전부가 "이것이 저것이 되었다"인데 그 한 프레임이 말을 무너뜨린다.
    ///
    /// 아직 못 받았으면 아래 어림값으로 그린다(첫 프레임에 잠깐 그렇다).
    var target: CGRect? = nil
    /// 입력 바까지 갈 것인가.
    ///
    /// **온보딩을 아직 안 넘긴 사람에게는 알약까지만 보인다.** 이 장면이 하는 말은
    /// "이 알약이 저 입력 바가 되었다"인데, 첫 실행에서는 스플래시가 끝나면 입력 바가
    /// 아니라 온보딩이 뜬다. 보여 준 적 없는 화면으로 변신해 놓고 그 위를 온보딩이
    /// 덮으면, 변신은 아무도 못 본 채 사라지고 말만 거짓이 된다.
    ///
    /// 온보딩을 넘긴 뒤부터는 스플래시 다음이 곧 찾기 화면이므로 끝까지 간다.
    var becomesInputBar: Bool = true
    var onDone: () -> Void = {}

    // MARK: 아이콘에서 가져온 비율
    //
    // 숫자를 여기서 새로 정하지 않는다. `Tools/make-icon.swift` 가 [22, 46, 30] 과
    // 높이 22 · 간격 9 로 굽고 있고, 그 비율이 곧 로고다. 화면에서는 알약 높이를
    // **입력 바 높이에 맞춰** 키운다 — 그래야 마지막에 세로로 늘어나거나 줄지 않는다.

    // 아이콘이 `あ` 와 밑줄 하나가 되면서 여기도 따라왔다. 알약 셋 중 가운데가
    // 입력 바가 되던 자리에, 이제 **밑줄이 입력 바가 된다** — 아이콘에서 사전이
    // 짚어 주던 그 선이 사용자가 칠 자리로 내려앉는다.
    private static let ratios: [CGFloat] = [46]
    private static let iconUnit: CGFloat = 22

    /// 글자 크기와 글자 아래 사이. 아이콘의 비율(글자 0.52 · 밑줄 굵기 0.055 ·
    /// 사이 0.075)을 화면에 옮긴 값이다. **아이콘의 값을 그대로 쓰지는 않는다** —
    /// 밑줄 굵기를 입력 바 높이에 맞추면 글자가 화면을 넘는다.
    private var glyphSize: CGFloat { barHeight * 1.7 }
    private var glyphGap: CGFloat { barHeight * 0.30 }
    /// 자리를 아직 못 받았을 때, 첫 한 프레임만 쓰는 어림값.
    ///
    /// **52 가 아니라 56 이다.** 글자 19 + 위아래 여백 14씩이면 52 여야 할 것 같지만,
    /// 실제로 재어 보니 56~57.5 로 그려진다(고운돋움이 그만큼 크게 앉는다).
    /// 이 4pt 가 마지막 한 프레임에서 눈에 띄던 어긋남이었다.
    private static let fallbackHeight: CGFloat = 56

    /// 알약 높이는 **입력 바 높이 그대로**다. 그래야 마지막에 세로로 늘어나거나 줄지 않는다.
    private var barHeight: CGFloat { target?.height ?? Self.fallbackHeight }
    private var scale: CGFloat { barHeight / Self.iconUnit }
    private var gap: CGFloat { 9 * scale }
    private var widths: [CGFloat] { Self.ratios.map { $0 * scale } }
    /// 입력 바가 되는 것. 이제 그리는 것이 밑줄 하나뿐이라 그것이 곧 주인공이다.
    private static let hero = 0

    /// 자리를 못 받았을 때 쓸 어림값.
    ///
    /// 입력 바가 제 자리를 알려 주면 그것을 쓰고, 못 받았을 때만 여기로 앉는다.
    /// 아이폰은 탭바 위, 아이패드는 화면 바닥에서 `screenBottom` 만큼 뜬 자리인데,
    /// 둘 사이의 어디쯤으로 둔다 — 한 프레임 어긋나는 것이 아예 딴 데로 앉는 것보다 낫다.
    private static let fallbackBottomInset: CGFloat = 56
    private static let barCorner: CGFloat = 18
    private var pillCorner: CGFloat { barHeight / 2 }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var arrived = [false]
    /// 변형은 **한 동작이 아니라 네 박자**다.
    ///
    /// 넷을 한꺼번에 하면 자리를 옮기는 중에 색까지 바뀌어, 중간에 정체를 알 수 없는
    /// 반투명 덩어리가 스친다. 사람 눈은 "무엇이 무엇으로 바뀌었나"를 보는데
    /// 그 사이가 흐릿하면 이어진 것으로 안 읽힌다.
    ///
    /// 곁의 둘이 비키고 · 주인공이 내려가고 · 가로로 펴지고 · 살갗을 입는다.
    /// 박자를 살짝씩 겹쳐 끊기지는 않게 한다.
    @State private var asideGone = false
    @State private var travelled = false
    @State private var stretched = false
    /// 색이 입력 바 쪽으로 옮겨 갔는가.
    @State private var tinted = false
    /// 다 옮긴 덮개가 걷혔는가.
    @State private var uncovered = false
    @State private var done = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.paper.ignoresSafeArea()

                // **글자가 먼저 서고 밑줄이 그 아래에 그어진다.** 아이콘 그대로다.
                // 밑줄이 입력 바 자리로 내려갈 때 글자는 제자리에서 물러난다 —
                // 따라가면 두 물건이 함께 이사하는 것으로 보이고, 이 장면이 하는 말
                // ("이 밑줄이 저 입력 바가 되었다")이 흐려진다.
                glyph(in: geo)

                ForEach(Array(widths.enumerated()), id: \.offset) { index, width in
                    pill(index: index, width: width, in: geo)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { finish() }
            .task { await play() }
        }
    }

    /// 아이콘의 `あ`. 밑줄 위에 선다.
    private func glyph(in geo: GeometryProxy) -> some View {
        Text("あ")
            .font(Theme.japanese(growing: glyphSize, weight: .medium))
            .foregroundStyle(Theme.ink)
            // 글자는 제 상자보다 작게 앉는다. 밑줄과의 사이를 눈으로 맞추려면
            // 상자가 아니라 잉크를 기준으로 재야 하는데, 화면에서는 그 값을 얻기
            // 어려우므로 상자 높이의 어림값으로 당긴다(아이콘을 구울 때와 같은 이유).
            .offset(y: yOffset(index: Self.hero, moved: false,
                               steppedAside: asideGone, in: geo)
                       - glyphSize * 0.62 - glyphGap)
            .scaleEffect(asideGone ? 0.92 : (arrived[Self.hero] ? 1 : 0.72))
            .opacity(arrived[Self.hero] && !asideGone ? 1 : 0)
    }

    // MARK: 알약 하나

    @ViewBuilder
    private func pill(index: Int, width: CGFloat, in geo: GeometryProxy) -> some View {
        let size = geo.size
        let isHero = index == Self.hero
        let moved = isHero && travelled
        let grown = isHero && stretched
        let steppedAside = !isHero && asideGone
        // 폭도 진짜 입력 바에서 가져온다. 못 받았을 때만 어림한다 —
        // 입력 바는 글이 시작하는 자리에 맞춰 좌우 24 를 두고 목록 폭을 넘지 않는다.
        let barWidth = target?.width ?? min(Theme.listWidth, size.width - Theme.gutter * 2)
        let nowWidth = grown ? barWidth : width
        let corner = grown ? Self.barCorner : pillCorner

        ZStack {
            // **완성된 입력 바를 검정 아래에 미리 깔아 둔다.**
            //
            // 처음에는 검정을 흐리게 하면서 유리를 겹쳐 올렸는데, 그 사이가 알약도
            // 입력 바도 아닌 **회색 덩어리**였다. 이 장면의 전부가 "이것이 저것이
            // 되었다"인데, 중간이 제3의 무엇이면 두 개를 잇지 못한다.
            //
            // 그래서 흐리게 하는 대신 **걷어낸다.** 아래에는 이미 다 된 입력 바가
            // 있고, 위를 덮은 검정이 왼쪽부터 물러난다 — 색이 바뀌는 것이 아니라
            // 덮개가 벗겨지는 것이라, 벗겨지는 내내 아래가 입력 바로 보인다.
            if isHero {
                barFace(corner: corner)
            }

            RoundedRectangle(cornerRadius: corner, style: .continuous)
                // **색이 서서히 입력 바 쪽으로 옮겨 간다.**
                //
                // 검정을 흐리게 해서 아래를 비치게 했더니, 그 사이가 알약도 입력 바도
                // 아닌 **회색 유령**이었다. 반투명한 검정이 유리 위에 얹히면 그렇게 된다.
                //
                // 그래서 투명해지는 것이 아니라 **불투명한 채로 밝아진다.** 검은 알약이
                // 입력 바의 톤까지 색을 옮긴 뒤, 이미 그 색이 되어 있으므로 걷혀도
                // 눈에 띄지 않는다 — 도형은 내내 한 덩어리로 남고 색만 바뀐다.
                .fill(tintedFill)
                .opacity(uncovered ? 0 : 1)
        }
        .frame(width: nowWidth, height: barHeight)
        .scaleEffect(steppedAside ? 0.55 : (arrived[index] ? 1 : 0.72))
        .opacity(opacity(index: index))
        .offset(x: moved ? heroX(in: geo) : centerX(index: index),
                y: yOffset(index: index, moved: moved,
                          steppedAside: steppedAside, in: geo))
    }

    /// 덮개의 색. 검정에서 입력 바의 톤으로 옮겨 간다.
    ///
    /// 도착점이 `grey4` 인 것은 종이 위에 얹힌 `.ultraThinMaterial` 이 실제로 그 언저리로
    /// 보이기 때문이다. 순백으로 가면 바가 배경에 녹아 한 번 사라졌다 나타나고,
    /// 회색에서 멈추면 걷힐 때 한 번 밝아진다.
    private var tintedFill: Color { tinted ? Theme.grey4 : Theme.ink }

    /// 입력 바의 얼굴 — 유리와 실선, 그리고 그 안에 놓이는 것들.
    ///
    /// 찾기 화면의 입력 바가 쓰는 값을 그대로 쓴다(반지름 18 · `.ultraThinMaterial` ·
    /// 회색 실선 0.5 · 좌우 18). **마지막 프레임이 진짜 입력 바와 같아야** 스플래시가
    /// 걷힌 자리에 같은 것이 남아, 화면이 넘어간 것이 아니라 이어진 것으로 읽힌다.
    ///
    /// 알약일 때는 검정에 통째로 가려 있다. 좁은 캡슐 안에서 글자가 눌리는 것은
    /// 보이지 않지만, 넘친 것이 밖으로 새지 않게 모양대로 잘라 둔다.
    private func barFace(corner: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Theme.grey3.opacity(0.5), lineWidth: 0.5)
            )
            .overlay(alignment: .leading) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.grey2)
                    Text("콘니치와")
                        .font(Theme.korean(.field))
                        // 진짜 자리표시와 같은 색이다. 회색 넷 중 하나를 고르면
                        // 마지막 프레임에서 글자 색만 달라 보인다.
                        .foregroundStyle(Theme.placeholder)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                // 덮개가 걷히는 것과 함께 들어온다. 덮개가 이미 같은 색이라
                // 글자만 나중에 떠오르는 것처럼 보인다.
                .opacity(uncovered ? 1 : 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }

    // MARK: 자리

    /// 셋을 가운데 모아 놓았을 때 이 알약의 중심.
    private func centerX(index: Int) -> CGFloat {
        let widths = self.widths
        let total = widths.reduce(0, +) + gap * CGFloat(widths.count - 1)
        var x = -total / 2
        for i in 0..<index { x += widths[i] + gap }
        return x + widths[index] / 2
    }

    /// 도착한 뒤의 가로 자리. 입력 바가 화면 한가운데가 아닐 수도 있으므로
    /// (아이패드에서 폭이 목록 폭에 걸리면 가운데 정렬된다) 그것도 받아서 쓴다.
    private func heroX(in geo: GeometryProxy) -> CGFloat {
        guard let target else { return 0 }
        let mine = geo.frame(in: .global)
        return target.midX - mine.midX
    }

    /// 통통 튀어 들어올 때는 위에서 떨어지고, 마지막에 주인공만 입력 바 자리로 내려간다.
    /// 곁의 둘은 비킬 때 살짝 가라앉는다 — 제자리에서 그냥 꺼지면 사라진 것이 아니라
    /// 깜빡인 것으로 보인다.
    private func yOffset(index: Int, moved: Bool, steppedAside: Bool,
                         in geo: GeometryProxy) -> CGFloat {
        if moved {
            // 진짜 입력 바의 중심으로 간다. 못 받았으면 어림한 자리로.
            guard let target else {
                return geo.size.height / 2 - barHeight / 2 - Self.fallbackBottomInset
            }
            let mine = geo.frame(in: .global)
            return target.midY - mine.midY
        }
        if steppedAside { return 18 }
        return arrived[index] ? 0 : -64
    }

    /// 곁의 둘은 주인공이 떠나기 **전에** 비킨다 — 남아 있으면 입력 바 곁에
    /// 뜻 없는 점 둘이 붙어 있는 꼴이 되고, 같이 움직이면 무엇을 봐야 할지 흩어진다.
    private func opacity(index: Int) -> Double {
        if !arrived[index] { return 0 }
        return (asideGone && index != Self.hero) ? 0 : 1
    }

    // MARK: 흐름

    private func play() async {
        guard !reduceMotion else { finish(); return }

        // **박자를 눈으로 셀 수 있을 만큼 둔다.** 처음엔 1초에 다 끝냈는데, 로고가
        // 섰다는 것을 알아보기도 전에 이미 입력 바가 되어 있었다. 무엇이 무엇으로
        // 바뀌었는지 보이지 않으면 이 장면은 아무 말도 하지 않는 셈이다.

        // **글자와 밑줄이 한 번에 통통 들어온다.** 알약 셋일 때는 하나씩 떨어뜨려
        // 셋이라는 것을 보여 줬는데, 지금 서는 것은 두 조각이 아니라 **글자 하나**다.
        // 나눠 떨어뜨리면 밑줄이 뒤늦게 붙는 부속처럼 보인다.
        //
        // 화면이 켜지자마자 튀어나오면 급해 보이므로 한 박자 두고 시작한다.
        await wait(140)
        guard !done else { return }
        // 통통 — 낮은 감쇠가 그 튐을 만든다. 앱이 쓰는 `.snappy` 는 튀지 않아서
        // 여기서만 스프링을 쓴다.
        //
        // **느긋하게 만드는 것은 `response` 다.** 감쇠(0.5)를 올리면 느려지는 대신
        // 튐이 사라져 통통이 아니라 스윽이 된다 — 그것은 뒤 변형 구간의 문법이다.
        withAnimation(.spring(response: 0.55, dampingFraction: 0.5)) {
            arrived[Self.hero] = true
        }

        // 셋이 다 선 채로 머무는 자리. **여기가 로고다.** 이 사이가 없으면
        // 알약이 들어오자마자 흩어져, 아이콘을 본 적이 없는 것이 된다.
        //
        // **셋째가 튀기를 마치는 것보다 길어야 한다.** 셋째는 540ms 에 떨어지기
        // 시작하고, 그 스프링(response 0.55 · 감쇠 0.5)은 첫 오버슈트가 되돌아오는
        // 600ms 께에야 눈에 멎은 것으로 보인다. 한때 420 이었는데 그러면 **셋째가
        // 아직 튀는 중에** 곁의 둘이 비키기 시작해, 통통이 다 보이기도 전에 변형이
        // 끼어들었다. 튐이 멎고 **한 박자 선 채로** 있어야 셋이 모여 로고라는 것이 읽힌다.
        //
        // 여기까지만 가는 길도 같은 값이다. 뒤에 올 변형이 없으니 이 사이가 곧 로고를
        // 보는 시간 전부인데, 튐을 다 보여 주고 한 박자 두는 길이가 마침 그만큼이다.
        await wait(760)
        guard !done else { return }

        // 온보딩이 뒤따르면 여기서 끝낸다. 글자와 밑줄이 선 채로 넘어간다.
        guard becomesInputBar else { finish(); return }

        // `asideGone` 이 이제 글자가 물러나는 것을 뜻한다. 곁의 알약이 비키던 자리를
        // 글자가 이어받았다 — 남는 것은 밑줄 하나이고, 그것이 입력 바가 된다.
        withAnimation(.snappy(duration: 0.32)) { asideGone = true }

        // 글자가 물러나기 시작하면 곧바로 밑줄이 내려간다. 다 사라진 뒤에 움직이면
        // 사이가 뜨고, 함께 움직이면 무엇을 봐야 할지 흩어진다.
        await wait(100)
        guard !done else { return }
        // 스윽 — 이쪽은 튀지 않는다. 도형이 자리를 옮기며 모양을 갈아입는 중에
        // 튀면 입력 바가 제자리를 못 찾은 것처럼 보인다.
        withAnimation(.spring(response: 0.58, dampingFraction: 0.9)) { travelled = true }

        // **펴지는 것이 내려가는 것보다 한 박자 늦다.** 같이 하면 매끄러운 덩어리
        // 하나가 흘러갈 뿐이고, 늦추면 "내려가서 · 펴진다" 두 동작으로 읽힌다 —
        // 그 두 번째가 이 장면이 하려는 말이다.
        await wait(120)
        guard !done else { return }
        withAnimation(.spring(response: 0.62, dampingFraction: 0.92)) { stretched = true }

        // 다 편 뒤에 색을 옮긴다. 펴는 중에 같이 밝아지면 무엇이 달라지고 있는지
        // 둘로 갈려, 어느 쪽도 눈에 남지 않는다.
        await wait(360)
        guard !done else { return }
        withAnimation(.easeInOut(duration: 0.5)) { tinted = true }

        // 색이 다 옮겨 간 뒤에 덮개를 걷는다. 이미 같은 색이라 걷히는 것이
        // 보이지 않고, 그 자리에 진짜 입력 바가 남는다.
        await wait(500)
        guard !done else { return }
        withAnimation(.easeOut(duration: 0.26)) { uncovered = true }

        await wait(300)
        finish()
    }

    private func wait(_ milliseconds: Int) async {
        try? await Task.sleep(for: .milliseconds(milliseconds))
    }

    private func finish() {
        guard !done else { return }
        done = true
        onDone()
    }
}
