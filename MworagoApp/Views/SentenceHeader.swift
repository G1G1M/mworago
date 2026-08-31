import SwiftUI
import MworagoCore

/// 되살린 원문 한 줄.
///
/// 문장을 치고 들어온 사람에게 문장을 돌려준다. 지금까지는 낱말 카드만 늘어놓아서
/// 원문을 사용자가 머릿속으로 이어 붙이고 있었다.
///
/// **가나가 맨 위다.** 낱말 카드와 같은 순서다 — 소리를 듣고 찾아온 사람에게 가장 가까운 것이
/// 가나이기 때문이다. 어디까지 볼지도 카드와 같은 다이얼이 정한다.
///
/// **되살린 문장은 들어 볼 수 있다.** 들린 대로 쳐서 찾아온 사람에게 돌려줄 것은
/// 결국 소리다 — 내가 들은 것이 이것이 맞는지는 다시 들어 봐야 안다.
///
/// 조각마다 누를 수 있다. **강조는 반전 하나로만** 한다 — 누르지 않았을 때 문장은
/// 평평하고, 누른 조각 하나만 검게 채워진다. 읽기 보조 다이얼과 같은 문법이라
/// 규칙을 새로 하나도 늘리지 않는다.
///
/// 겸사겸사 분절이 눈에 보이게 된다. 어디서 끊겼는지 문장 위에 그대로 드러나므로
/// 잘못 끊긴 것을 사용자가 바로 알아챈다.
///
/// **화면에서 가장 큰 글자가 여기 있다.** 사용자가 친 것은 문장이고 카드는 그것을
/// 뜯어본 것이라, 문장이 카드보다 작으면 조각이 원본보다 세 보인다.
/// 44 대 26 으로 벌려 한눈에 갈리게 했다 — 문장을 키우는 것만으로는 모자라서
/// 카드를 함께 내렸다(둘 다 30 언저리면 몇 포인트 차이는 눈에 띄지 않는다).
struct SentenceHeader: View {
    let segments: [Segment]
    let aid: ReadingAid
    /// 지금 고른 조각. 아무것도 안 골랐으면 nil 이고, 그때가 기본 상태다.
    @Binding var selected: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 이 덩어리가 무엇인지 한 낱말로 말해 준다.
            //
            // 크기만으로는 "큰 카드"로 읽힌다 — 아래 카드들과 생김새가 같고 사이에 놓인 선도
            // 같아서, 첫 번째 조각으로 보인다. 색을 더하는 길도 있지만 **강조는 반전 하나로만**
            // 쓰기로 했으므로, 이름과 여백으로 가른다.
            HStack(spacing: 9) {
                Text("문장")
                    .font(Theme.korean(12))
                    .foregroundStyle(Theme.grey3)
                SpeakButton(text: segments.kana, size: 13)
            }

            pieces

            if aid.showsHangul {
                Text(segments.map(\.hangul).joined())
                    .font(Theme.korean(16))
                    .foregroundStyle(Theme.grey3)
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 24)
        // 아래를 카드보다 훨씬 크게 벌린다. 카드끼리는 18 + 18 로 붙어 있고 이쪽은 32 + 18 이라,
        // 같은 굵기의 선을 사이에 두고도 "여기서 한 덩어리가 끝난다"가 읽힌다.
        .padding(.bottom, 32)
    }

    /// 조각들을 이어 붙인 한 줄. 일본어는 띄어 쓰지 않으므로 사이를 벌리지 않고,
    /// 대신 누른 조각의 배경으로만 경계를 보인다.
    private var pieces: some View {
        // 줄 사이는 벌리고 글자 사이는 붙인다. 44 로 키우자 세 줄이 다닥다닥 붙어 답답해졌는데,
        // 가로로 벌릴 수는 없다 — 일본어는 띄어 쓰지 않으므로 되살린 문장도 붙어 있어야 한다.
        FlowRow(lineSpacing: 8) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                let isSelected = selected == index
                Button {
                    // 같은 것을 다시 누르면 놓는다. 고른 상태에서 빠져나갈 길이 있어야 한다.
                    withAnimation(.snappy(duration: 0.18)) {
                        selected = isSelected ? nil : index
                    }
                } label: {
                    // 가로로는 한 픽셀도 벌리지 않는다. 되살린 문장이라 원문처럼 붙어 있어야 하고,
                    // 조각의 경계는 눌렀을 때 배경으로만 드러낸다.
                    //
                    // 여기 놓이는 가나는 **표면형**이다. 카드는 표제어를 보이는 자리라 사전형이 맞지만
                    // (やめる), 문장은 사용자가 한 말을 되살리는 자리다 (やめろ).
                    Text(segment.kana)
                        .font(Theme.japanese(44, weight: .medium))
                        .padding(.vertical, 4)
                        .background(isSelected ? Theme.ink : .clear,
                                    in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .foregroundStyle(pieceColor(segment, selected: isSelected))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// 못 찾은 조각은 흐리게 둔다 — 문장에 난 구멍이 보여야 어디가 틀렸는지 안다.
    private func pieceColor(_ segment: Segment, selected: Bool) -> Color {
        if selected { return Theme.paper }
        return segment.results.isEmpty ? Theme.grey3 : Theme.ink
    }
}

/// 넘치면 다음 줄로 흘려보내는 가로 배치.
///
/// 긴 문장은 한 줄에 다 들어가지 않는데, `HStack` 은 넘쳐도 줄을 바꾸지 않고
/// 글자를 줄여 버린다. 조각 하나하나가 눌러야 하는 것이라 통째로 `Text` 로 만들 수도 없다.
///
/// **벌리는 것은 줄 사이뿐이다.** 조각과 조각 사이는 언제나 0 이라 아예 값을 받지 않는다 —
/// 일본어는 띄어 쓰지 않으므로 되살린 문장도 원문처럼 붙어 있어야 한다.
/// 넘치면 줄을 바꾸는 가로 배치.
///
/// 문장 헤더와 도감이 함께 쓴다 — `HStack` 은 넘치면 줄을 바꾸는 대신 글자를 줄여 버린다.
struct FlowRow: Layout {
    var lineSpacing: CGFloat = 0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                                      proposal: ProposedViewSize(size))
                x += size.width
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !row.indices.isEmpty, row.width + size.width > width {
                rows.append(row)
                row = Row()
            }
            row.indices.append(index)
            row.width += size.width
            row.height = max(row.height, size.height)
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}
