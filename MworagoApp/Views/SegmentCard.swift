import SwiftUI
import MworagoCore

/// 낱말 한 조각의 결과.
///
/// 세 층으로 보인다 — **가나 · 한자 · 한글**. 어디까지 보여줄지는 사용자가 정한다.
/// 가나가 맨 위인 것은 소리를 듣고 찾아온 사람에게 가장 가까운 것이 가나이기 때문이다.
/// 활용형이면 무엇을 되돌렸는지도 말해 준다. 낱말만 던져 주는 것과
/// "止める의 명령형"이라고 알려 주는 것은 교재로서 값이 다르다.
struct SegmentCard: View {
    let segment: Segment
    let aid: ReadingAid

    private var top: SearchResult? { segment.results.first }
    private var alternates: [SearchResult] { Array(segment.results.dropFirst().prefix(2)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let top {
                headline(top)
                if !top.entry.displayGloss.isEmpty {
                    Text(top.entry.displayGloss)
                        .font(Theme.korean(15))
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
    }

    // MARK: 첫 번째 답

    private func headline(_ result: SearchResult) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(result.reading)
                    .font(Theme.japanese(34, weight: .medium))
                    .foregroundStyle(Theme.ink)

                if let rule = result.deinflection {
                    // 되돌린 활용은 회색 꼬리표로. 강조를 나눠 갖지 않는다.
                    Text(rule)
                        .font(Theme.korean(12))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.grey4, in: Capsule())
                        .foregroundStyle(Theme.grey1)
                }
            }

            // 가나로만 쓰는 낱말은 표기가 읽기와 같다. 같은 것을 두 번 보일 필요는 없다.
            if aid.showsKanji, result.headword != result.reading {
                Text(result.headword)
                    .font(Theme.japanese(21))
                    .foregroundStyle(Theme.grey1)
            }
            if aid.showsHangul {
                Text(segment.hangul)
                    .font(Theme.korean(15))
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
                        .font(Theme.japanese(18))
                        .foregroundStyle(Theme.grey1)
                    Text(result.entry.koreanGloss ?? result.entry.glosses.first ?? "")
                        .font(Theme.korean(13))
                        .foregroundStyle(Theme.grey2)
                        .lineLimit(1)
                }
            }
        }
        .padding(.top, 2)
    }

    /// 이 후보를 첫 줄의 답과 갈라 주는 것.
    private func distinguisher(_ result: SearchResult) -> String {
        if aid.showsKanji, result.headword != result.reading { return result.headword }
        // 한자를 끈 상태이거나 가나로만 쓰는 낱말이라면, 읽기가 다를 때만 그것으로 가른다.
        // 그마저 같으면 뜻만 남는다 — 그때는 뜻이 유일한 구분점이다.
        return result.reading == top?.reading ? "" : result.reading
    }

    // MARK: 못 찾은 조각

    private var notFound: some View {
        HStack(spacing: 10) {
            Text(segment.hangul)
                .font(Theme.korean(19))
                .foregroundStyle(Theme.grey2)
            Text("사전에 없어요")
                .font(Theme.korean(13))
                .foregroundStyle(Theme.grey3)
        }
    }
}
