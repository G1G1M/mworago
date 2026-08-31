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
    /// 담아 두는 곳. 없으면 갈피표를 그리지 않는다 — 미리보기와 테스트를 위해서다.
    var collection: CollectionStore? = nil

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

                if let collection {
                    Spacer(minLength: 8)
                    bookmark(result, in: collection)
                }
            }

            // 가나로만 쓰는 낱말은 표기가 읽기와 같다. 같은 것을 두 번 보일 필요는 없지만,
            // **자리는 비워 둔다.** 줄을 통째로 빼면 아래가 위로 올라와서, 카드마다
            // 한글 음차가 다른 높이에 놓인다 — 옆으로 늘어선 카드에서는 그 어긋남이
            // 바로 보이고, 같은 것을 찾는 눈이 매번 다시 헤맨다.
            // 문장 머리는 하나뿐이라 이 문제가 없어 그쪽은 지금대로 둔다.
            if aid.showsKanji {
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    if result.headword != result.reading {
                        Text(result.headword)
                            .font(Theme.japanese(18))
                            .foregroundStyle(Theme.grey1)
                        if let reading = hanja.reading(of: result.headword) {
                            Text(reading)
                                .font(Theme.korean(13))
                                .foregroundStyle(Theme.grey3)
                        }
                    } else {
                        Text(" ")
                            .font(Theme.japanese(18))
                            .accessibilityHidden(true)
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

    /// 담기.
    ///
    /// **자동으로 모으지 않는다.** 찾아본 것을 다 쌓으면 오타와 헛짚은 것까지 교재가 된다.
    /// 무엇이 내게 걸린 말이었는지는 사용자만 안다.
    ///
    /// 담긴 것은 채워진 갈피표다. 강조를 색으로 나누지 않으므로 채움과 비움으로만 가른다.
    private func bookmark(_ result: SearchResult, in collection: CollectionStore) -> some View {
        let word = CollectedWord(headword: result.headword,
                                 reading: result.reading,
                                 hangul: segment.hangul,
                                 gloss: result.entry.displayGloss)
        let held = collection.contains(word)
        return Button {
            collection.toggle(word)
        } label: {
            Image(systemName: held ? "bookmark.fill" : "bookmark")
                .font(.system(size: 15))
                .foregroundStyle(held ? Theme.ink : Theme.grey3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(held ? "\(result.headword) 빼기" : "\(result.headword) 담기")
    }

    // MARK: 나머지 후보
    //
    // 1위가 정답인 비율은 93%지만 3위 안에 있을 비율은 98%다.
    // 그 5%를 사용자가 직접 고를 수 있게 곁에 둔다.

    /// 대안 후보도 **첫 줄과 같은 차례로** 쌓는다 — 가나가 먼저, 한자가 그 아래.
    ///
    /// 한때는 "첫 줄과 무엇이 다른지"에 따라 한자를 보이기도 하고 가나를 보이기도 했다.
    /// 대안들은 같은 소리를 내는 낱말이라 가나가 대개 겹치므로, 다른 것만 보이면
    /// 짧아진다는 생각이었다.
    ///
    /// **그런데 짧아지는 대신 낱말마다 층이 달라졌다.** 어떤 후보는 한자 한 줄로,
    /// 어떤 후보는 가나 한 줄로 나와서, 한 화면 안에서 같은 자리에 다른 것이 놓였다.
    /// 눈은 자리로 읽는다 — 위가 소리, 아래가 글자라는 것이 화면 어디서나 같아야
    /// 무엇을 보고 있는지 매번 다시 판단하지 않는다. 조금 겹치더라도 차례를 지킨다.
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
                    // 첫 줄과 같은 규칙이다. 가나로만 쓰는 낱말은 보일 것이 없지만
                    // **자리는 남긴다** — 다이얼이 켠 층이 낱말에 따라 사라지면
                    // 같은 버튼이 어떤 때는 듣고 어떤 때는 안 듣는 것이 된다.
                    if aid.showsKanji {
                        Text(result.headword != result.reading ? result.headword : " ")
                            .font(Theme.japanese(13))
                            .foregroundStyle(Theme.grey2)
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
