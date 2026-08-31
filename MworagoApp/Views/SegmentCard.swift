import SwiftUI
import MworagoCore

/// 낱말 한 조각의 결과.
///
/// 두 층으로 보인다 — **가나 · 한글**. 어디까지 보여줄지는 사용자가 정한다.
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
    /// 문장에서 이 조각을 골랐는가.
    ///
    /// 고른 카드는 왼쪽에 선 하나를 세워 표시한다. 문장 쪽 강조가 이미 반전이라
    /// 여기까지 반전하면 화면에 검은 덩어리가 둘이 되어 어느 쪽이 답인지 흐려진다.
    var isSelected: Bool = false
    /// 담아 두는 곳. 없으면 갈피표를 그리지 않는다 — 미리보기와 테스트를 위해서다.
    var collection: CollectionStore? = nil
    /// 담아 달라고 위로 알린다. **카드가 직접 담지 않는다** — 어디에 넣을지 묻는 모달은
    /// 화면에 하나여야 하는데, 카드마다 시트를 달면 조각 수만큼 생긴다.
    var onCollect: (CollectedWord) -> Void = { _ in }

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
        .padding(.horizontal, Theme.gutter)
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

                Spacer(minLength: 8)
                SpeakButton(text: result.reading)
                if let collection {
                    bookmark(result, in: collection)
                }
            }

            if aid.showsHangul {
                Text(segment.hangul)
                    .font(Theme.korean(14))
                    .foregroundStyle(Theme.grey3)
            }
        }
    }

    /// 담기.
    ///
    /// **자동으로 모으지 않는다.** 찾아본 것을 다 쌓으면 오타와 헛짚은 것까지 교재가 된다.
    /// 무엇이 내게 걸린 말이었는지는 사용자만 안다.
    ///
    /// 담긴 것은 채워진 갈피표다. 강조를 색으로 나누지 않으므로 채움과 비움으로만 가른다.
    ///
    /// **담을 때는 어디에 넣을지 묻고, 뺄 때는 묻지 않는다.** 무르는 일에까지 확인을
    /// 붙이면 잘못 누른 것을 되돌리는 데 두 번이 든다.
    private func bookmark(_ result: SearchResult, in collection: CollectionStore) -> some View {
        let word = CollectedWord(headword: result.headword,
                                 reading: result.reading,
                                 hangul: segment.hangul,
                                 gloss: result.entry.displayGloss)
        let held = collection.contains(word)
        return Button {
            if held { collection.remove(word) } else { onCollect(word) }
        } label: {
            Image(systemName: held ? "bookmark.fill" : "bookmark")
                .font(.system(size: 15))
                .foregroundStyle(held ? Theme.ink : Theme.grey3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(held ? "\(result.reading) 빼기" : "\(result.reading) 담기")
    }

    // MARK: 나머지 후보
    //
    // 1위가 정답인 비율은 93%지만 3위 안에 있을 비율은 98%다.
    // 그 5%를 사용자가 직접 고를 수 있게 곁에 둔다.

    /// 대안 후보는 **가나와 뜻 한 줄**이다.
    ///
    /// 한자를 빼면서 같은 소리의 다른 낱말들이 **같은 가나로 늘어선다** — `かみ` 를 찾으면
    /// 종이 · 신 · 머리카락이 전부 `かみ` 다. 가르는 것은 이제 뜻뿐이므로, 뜻을 자르지 않고
    /// 한 줄을 다 내준다.
    private var alternateList: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(Array(alternates.enumerated()), id: \.offset) { _, result in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(result.reading)
                            .font(Theme.japanese(16))
                            .foregroundStyle(Theme.grey1)
                        Text(result.entry.koreanGloss ?? result.entry.glosses.first ?? "")
                            .font(Theme.korean(12))
                            .foregroundStyle(Theme.grey2)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.top, 2)
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
