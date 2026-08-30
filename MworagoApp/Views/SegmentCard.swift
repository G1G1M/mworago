import SwiftUI
import MworagoCore

/// 낱말 한 조각의 결과.
///
/// 세 층으로 보인다 — **가나 · 한자 · 한글**. 어디까지 보여줄지는 사용자가 정한다.
/// 가나가 맨 위인 것은 소리를 듣고 찾아온 사람에게 가장 가까운 것이 가나이기 때문이다.
/// 활용형이면 무엇을 되돌렸는지도 말해 준다. 낱말만 던져 주는 것과
/// "止める의 명령형"이라고 알려 주는 것은 교재로서 값이 다르다.
///
/// **카드는 문장보다 작다.** 사용자가 친 것은 문장이고 이 카드들은 그것을 뜯어본 것이라,
/// 카드가 더 크면 조각이 원본보다 세 보인다. 문장 44 에 맞춰 26 으로 내렸고,
/// 아래 층들도 함께 따라 내려 카드 안의 차례는 그대로 뒀다.
struct SegmentCard: View {
    let segment: Segment
    let aid: ReadingAid
    /// 한자의 한국 독음. 뜻이 아니라 단서라, 뜻 자리가 아니라 한자 곁에 둔다.
    var hanja: HanjaReading = HanjaReading(tsv: "")
    /// 문장에서 이 조각을 골랐는가.
    ///
    /// 고른 카드는 왼쪽에 선 하나를 세워 표시한다. 문장 쪽 강조가 이미 반전이라
    /// 여기까지 반전하면 화면에 검은 덩어리가 둘이 되어 어느 쪽이 답인지 흐려진다.
    var isSelected: Bool = false

    private var top: SearchResult? { segment.results.first }
    /// 1위와 같은 낱말은 걸러진 채로 온다 — 大丈夫 가 두 번 보이지 않도록.
    private var alternates: [SearchResult] { segment.alternates() }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let top {
                headline(top)
                if !top.entry.displayGloss.isEmpty {
                    Text(top.entry.displayGloss)
                        .font(Theme.korean(14))
                        .foregroundStyle(Theme.grey1)
                }
                if !alternates.isEmpty { alternateList }
            } else {
                notFound
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .overlay(alignment: .leading) {
            Theme.ink
                .frame(width: 3)
                .opacity(isSelected ? 1 : 0)
        }
    }

    // MARK: 첫 번째 답

    private func headline(_ result: SearchResult) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(result.reading)
                    .font(Theme.japanese(26, weight: .medium))
                    .foregroundStyle(Theme.ink)

                if let rule = result.deinflection {
                    // 되돌린 활용은 회색 꼬리표로. 강조를 나눠 갖지 않는다.
                    Text(rule)
                        .font(Theme.korean(11))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.grey4, in: Capsule())
                        .foregroundStyle(Theme.grey1)
                }
            }

            // 가나로만 쓰는 낱말은 표기가 읽기와 같다. 같은 것을 두 번 보일 필요는 없다.
            if aid.showsKanji, result.headword != result.reading {
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Text(result.headword)
                        .font(Theme.japanese(18))
                        .foregroundStyle(Theme.grey1)
                    if let reading = hanja.reading(of: result.headword) {
                        Text(reading)
                            .font(Theme.korean(13))
                            .foregroundStyle(Theme.grey3)
                    }
                }
            }
            if aid.showsHangul {
                Text(segment.hangul)
                    .font(Theme.korean(14))
                    .foregroundStyle(Theme.grey3)
            }
        }
    }

    // MARK: 나머지 후보
    //
    // 1위가 정답인 비율은 93%지만 3위 안에 있을 비율은 98%다.
    // 그 5%를 사용자가 직접 고를 수 있게 곁에 둔다.

    private var alternateList: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(alternates.enumerated()), id: \.offset) { _, result in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    // 첫 줄에서는 가나가 주인공이지만, 여기서는 아니다.
                    // 대안들은 같은 소리를 내는 다른 낱말이라 가나가 모두 같다 —
                    // 무엇이 다른지 말해 주는 것은 한자다.
                    Text(distinguisher(result))
                        .font(Theme.japanese(16))
                        .foregroundStyle(Theme.grey1)
                    Text(result.entry.koreanGloss ?? result.entry.glosses.first ?? "")
                        .font(Theme.korean(12))
                        .foregroundStyle(Theme.grey2)
                        .lineLimit(1)
                }
            }
        }
        .padding(.top, 2)
    }

    /// 이 후보를 첫 줄의 답과 갈라 주는 것.
    ///
    /// **첫 줄과 무엇이 다른지가 곧 이 후보의 이름이다.** 한자가 다르면 한자로,
    /// 한자가 같다면 소리로 가른다(机 つくえ · つき). 둘 다 같은 후보는 애초에
    /// `alternates()` 가 걸러 내므로 여기까지 오지 않는다.
    private func distinguisher(_ result: SearchResult) -> String {
        guard let top else { return result.headword }
        if aid.showsKanji, result.headword != top.headword { return result.headword }
        if result.reading != top.reading { return result.reading }
        return aid.showsKanji ? result.headword : ""
    }

    // MARK: 못 찾은 조각

    private var notFound: some View {
        HStack(spacing: 10) {
            Text(segment.hangul)
                .font(Theme.korean(17))
                .foregroundStyle(Theme.grey2)
            Text("사전에 없어요")
                .font(Theme.korean(12))
                .foregroundStyle(Theme.grey3)
        }
    }
}
