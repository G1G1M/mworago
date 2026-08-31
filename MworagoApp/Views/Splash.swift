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
    var onDone: () -> Void = {}

    // MARK: 아이콘에서 가져온 비율
    //
    // 숫자를 여기서 새로 정하지 않는다. `Tools/make-icon.swift` 가 [22, 46, 30] 과
    // 높이 22 · 간격 9 로 굽고 있고, 그 비율이 곧 로고다. 화면에서는 알약 높이를
    // **입력 바 높이에 맞춰** 키운다 — 그래야 마지막에 세로로 늘어나거나 줄지 않는다.

    private static let ratios: [CGFloat] = [22, 46, 30]
    private static let iconUnit: CGFloat = 22
    /// 입력 바 높이(글자 19 + 위아래 여백 14씩)에 맞춘 값이다.
    private static let barHeight: CGFloat = 52
    private static let scale = barHeight / iconUnit
    private static let gap: CGFloat = 9 * scale
    private static var widths: [CGFloat] { ratios.map { $0 * scale } }
    /// 가운데 알약. 가장 길고, 이것이 입력 바가 된다.
    private static let hero = 1

    /// 입력 바가 실제로 놓이는 자리 — 탭바 위에 14 를 띄운 곳.
    private static let barBottomInset: CGFloat = 63
    private static let barCorner: CGFloat = 18
    private static let pillCorner = barHeight / 2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var arrived = [false, false, false]
    @State private var morphed = false
    @State private var done = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.paper.ignoresSafeArea()

                ForEach(Array(Self.widths.enumerated()), id: \.offset) { index, width in
                    pill(index: index, width: width, in: geo.size)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { finish() }
            .task { await play() }
        }
    }

    // MARK: 알약 하나

    @ViewBuilder
    private func pill(index: Int, width: CGFloat, in size: CGSize) -> some View {
        let isHero = index == Self.hero
        let morphing = morphed && isHero
        // 입력 바는 글이 시작하는 자리에 맞춰 좌우 24 를 두고, 목록 폭을 넘지 않는다.
        let barWidth = min(Theme.listWidth, size.width - Theme.gutter * 2)

        RoundedRectangle(cornerRadius: morphing ? Self.barCorner : Self.pillCorner,
                         style: .continuous)
            .fill(Theme.ink)
            // 검은 알약이 그대로 남으면 화면이 넘어가는 순간 유리 바로 튄다.
            // 모양이 바뀌는 동안 속도 같이 갈아입는다.
            .opacity(morphing ? 0 : 1)
            .overlay { if isHero { barSkin(morphing: morphing) } }
            .frame(width: morphing ? barWidth : width, height: Self.barHeight)
            .scaleEffect(arrived[index] ? 1 : 0.72)
            .opacity(opacity(index: index))
            .offset(x: morphing ? 0 : centerX(index: index),
                    y: destinationY(index: index, morphing: morphing, in: size))
    }

    /// 입력 바의 살갗 — 유리와 실선, 그리고 그 안에 놓이는 것들.
    /// 찾기 화면이 쓰는 것과 같은 값이라 넘어갈 때 이어 붙는다.
    private func barSkin(morphing: Bool) -> some View {
        RoundedRectangle(cornerRadius: Self.barCorner, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: Self.barCorner, style: .continuous)
                    .strokeBorder(Theme.grey3.opacity(0.5), lineWidth: 0.5)
            )
            .overlay(alignment: .leading) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.grey2)
                    Text("다이죠부")
                        .font(Theme.korean(19))
                        .foregroundStyle(Theme.grey3)
                }
                .padding(.horizontal, 18)
                // 글자는 바가 다 자란 뒤에 나타난다. 자라는 내내 붙어 있으면
                // 좁은 알약 안에서 글자가 눌려 보인다.
                .opacity(morphing ? 1 : 0)
            }
            .opacity(morphing ? 1 : 0)
    }

    // MARK: 자리

    /// 셋을 가운데 모아 놓았을 때 이 알약의 중심.
    private func centerX(index: Int) -> CGFloat {
        let widths = Self.widths
        let total = widths.reduce(0, +) + Self.gap * CGFloat(widths.count - 1)
        var x = -total / 2
        for i in 0..<index { x += widths[i] + Self.gap }
        return x + widths[index] / 2
    }

    /// 통통 튀어 들어올 때는 위에서 떨어지고, 마지막에 주인공만 입력 바 자리로 내려간다.
    private func destinationY(index: Int, morphing: Bool, in size: CGSize) -> CGFloat {
        if morphing { return size.height / 2 - Self.barHeight / 2 - Self.barBottomInset }
        return arrived[index] ? 0 : -64
    }

    /// 곁의 둘은 주인공이 떠날 때 함께 사라진다 — 남아 있으면 입력 바 곁에
    /// 뜻 없는 점 둘이 붙어 있는 꼴이 된다.
    private func opacity(index: Int) -> Double {
        if !arrived[index] { return 0 }
        return (morphed && index != Self.hero) ? 0 : 1
    }

    // MARK: 흐름

    private func play() async {
        guard !reduceMotion else { finish(); return }

        for index in Self.ratios.indices {
            try? await Task.sleep(for: .milliseconds(index == 0 ? 70 : 95))
            guard !done else { return }
            // 통통 — 낮은 감쇠가 그 튐을 만든다. 앱이 쓰는 `.snappy` 는 튀지 않아서
            // 여기서만 스프링을 쓰되, 값 하나로 셋을 다 그린다.
            withAnimation(.spring(response: 0.38, dampingFraction: 0.52)) {
                arrived[index] = true
            }
        }

        try? await Task.sleep(for: .milliseconds(280))
        guard !done else { return }
        // 스윽 — 이쪽은 튀지 않는다. 도형이 자리를 옮기며 모양을 갈아입는 중에
        // 튀면 입력 바가 제자리를 못 찾은 것처럼 보인다.
        withAnimation(.spring(response: 0.52, dampingFraction: 0.86)) { morphed = true }

        try? await Task.sleep(for: .milliseconds(430))
        finish()
    }

    private func finish() {
        guard !done else { return }
        done = true
        onDone()
    }
}
