import SwiftUI
import MworagoCore

/// 가나 표 — 히라가나와 가타카나를 한글 음차와 나란히 놓는다.
///
/// **이 앱에서 유일하게 사전이 필요 없는 자료다.** 가나는 마흔여섯 자에 탁음과 요음이
/// 붙는 것이 전부이고 그 표는 천 년째 고정돼 있다. JMdict 도 빈도도 모델도 쓰지 않으므로
/// **틀릴 여지가 없다** — 뜻처럼 넷 중 하나가 틀리는 일이 여기서는 일어나지 않는다.
///
/// 왜 필요한가. 이 앱은 읽기 보조 다이얼로 한글을 켜고 끌 수 있게 해 두었는데,
/// 그것은 못 읽는 순간을 **그때그때 넘기는** 방편이다. 넘기기만 하면 영영 못 읽는다.
/// 표는 그 방편이 필요 없어지는 쪽이다.
///
/// 한글 음차는 화면에 적어 두지 않고 `KanaToHangul` 로 그 자리에서 만든다.
/// 검색이 쓰는 것과 **같은 규칙**이라야, 표에서 배운 대로 쳤을 때 실제로 찾아진다.
struct KanaSheet: View {
    @Environment(\.dismiss) private var dismiss
    /// 가타카나로 넘겨 볼 수 있다. 같은 소리의 두 글자를 나란히 두지 않는 것은,
    /// 한 번에 둘을 외우려 들면 둘 다 흐려지기 때문이다.
    @State private var katakana = false

    private static let contentWidth: CGFloat = 520

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    Text("가나는 소리 글자예요. 표를 다 외우지 않아도, 찾다 막힐 때 여기서 확인하면 됩니다.")
                        .font(Theme.korean(15))
                        .foregroundStyle(Theme.grey1)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)

                    dial

                    ForEach(KanaTable.charts, id: \.title) { chart in
                        chartBlock(chart)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
                .frame(maxWidth: Self.contentWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.paper)
            .navigationTitle("가나 표")
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
                Text(katakana ? KanaTable.toKatakana(kana) : kana)
                    .font(Theme.japanese(24))
                    .foregroundStyle(Theme.ink)
                Text(KanaToHangul.transliterate(kana))
                    .font(Theme.korean(12))
                    .foregroundStyle(Theme.grey3)
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
