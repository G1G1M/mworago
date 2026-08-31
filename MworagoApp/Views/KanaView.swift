import SwiftUI
import MworagoCore

/// 글자 — 가나를 보고, 듣고, 익힌다.
///
/// 연습 안의 쪽지였던 것을 탭으로 올렸다. **가나를 못 읽어서 멈추는 순간**은 찾을 때도
/// 연습할 때도 생기는데, 쪽지로는 연습 화면에서만 닿았다.
///
/// 낱말 탭이 **낱말**을 모으는 자리라면 이쪽은 **글자**다. 둘을 가른 것은 배우는 차례가
/// 다르기 때문이다 — 글자는 마흔여섯 자로 끝나지만 낱말은 끝이 없다.
struct KanaView: View {
    enum Mode: Int, CaseIterable, Identifiable {
        case chart, quiz
        var id: Int { rawValue }
        var label: String {
            switch self {
            case .chart: "표"
            case .quiz: "익히기"
            }
        }
    }

    @State private var mode: Mode = ProcessInfo.processInfo.arguments.contains("--quiz") ? .quiz : .chart
    /// 가타카나로 넘겨 볼 수 있다. 같은 소리의 두 글자를 나란히 두지 않는 것은,
    /// 한 번에 둘을 외우려 들면 둘 다 흐려지기 때문이다.
    @State private var katakana = false
    /// 펼쳐 보고 있는 글자. `--kana=あ` 로 띄운 채 시작할 수 있다.
    @State private var detail: Glyph? = ProcessInfo.processInfo.arguments
        .first { $0.hasPrefix("--kana=") }
        .map { Glyph(kana: String($0.dropFirst("--kana=".count))) }

    /// 시트에 실어 보내려면 무엇으로 식별되는지가 있어야 한다. 글자가 곧 그것이다.
    struct Glyph: Identifiable {
        let kana: String
        var id: String { kana }
    }

    private static let contentWidth: CGFloat = Theme.readWidth

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper.ignoresSafeArea()
                switch mode {
                case .chart: chart
                case .quiz:  KanaQuiz()
                }
            }
            .navigationTitle("글자")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { modeDial }
            }
            .sheet(item: $detail) { glyph in KanaDetail(kana: glyph.kana, katakana: katakana) }
        }
    }

    /// 표와 익히기를 가른다. 읽기 보조 다이얼과 같은 문법이다.
    private var modeDial: some View {
        HStack(spacing: 6) {
            ForEach(Mode.allCases) { option in
                let selected = option == mode
                Button {
                    withAnimation(.snappy(duration: 0.18)) { mode = option }
                } label: {
                    Text(option.label)
                        .font(Theme.korean(13, weight: selected ? .semibold : .regular))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selected ? Theme.ink : .clear, in: Capsule())
                        .foregroundStyle(selected ? Theme.paper : Theme.grey2)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var chart: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Text("가나는 소리 글자예요.\n표를 다 외우지 않아도, 찾다 막힐 때 여기서 확인하면 됩니다.")
                    .font(Theme.korean(15))
                    .foregroundStyle(Theme.grey1)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)

                dial

                ForEach(KanaTable.charts, id: \.title) { chartData in
                    chartBlock(chartData)
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 36)
            .frame(maxWidth: Self.contentWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    /// 읽기 보조 다이얼과 같은 문법 — 평평하고, 고른 것 하나만 검게 채워진다.
    private var dial: some View {
        HStack(spacing: 6) {
            ForEach([false, true], id: \.self) { isKatakana in
                let selected = isKatakana == katakana
                Button {
                    withAnimation(.snappy(duration: 0.18)) { katakana = isKatakana }
                } label: {
                    Text(isKatakana ? "가타카나" : "히라가나")
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

    private func chartBlock(_ chart: KanaTable.Chart) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text(chart.title)
                    .font(Theme.korean(12))
                    .tracking(0.6)
                    .foregroundStyle(Theme.grey2)
                Rectangle().fill(Theme.grey3).frame(height: 0.5)
            }

            // 격자로 세운다. 오십음도는 자리가 곧 뜻이라 — 어느 행 어느 단인지가
            // 그 글자의 소리를 말해 준다 — 칸이 어긋나면 표가 아니라 목록이 된다.
            Grid(horizontalSpacing: 4, verticalSpacing: 12) {
                ForEach(Array(chart.rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, kana in
                            cell(kana)
                        }
                    }
                }
            }
        }
    }

    /// 한 칸. 빈 자리(ゐ·ゑ 처럼 현대에 안 쓰는 소리)는 비워 두되 **자리는 지킨다** —
    /// 없는 칸을 접으면 아래 글자가 위로 올라와 행과 단이 어긋난다.
    @ViewBuilder
    private func cell(_ kana: String?) -> some View {
        VStack(spacing: 3) {
            if let kana {
                // 누르면 그 글자 하나의 자리로. 표는 훑는 곳이고, 소리를 듣거나
                // 자세히 볼 일은 글자마다 따로 생긴다.
                Button { detail = Glyph(kana: kana) } label: {
                    VStack(spacing: 3) {
                        Text(katakana ? KanaTable.toKatakana(kana) : kana)
                            .font(Theme.japanese(24))
                            .foregroundStyle(Theme.ink)
                        Text(KanaToHangul.transliterate(kana))
                            .font(Theme.korean(12))
                            .foregroundStyle(Theme.grey3)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Text(" ")
                    .font(Theme.japanese(24))
                Text(" ")
                    .font(Theme.korean(12))
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
