import SwiftUI
import MworagoCore

/// 낱말 한 조각의 결과.
///
/// 세 줄이다 — **가나 · 한글 발음 · 한국어 뜻**. 가나가 맨 위인 것은 소리를 듣고
/// 찾아온 사람에게 가장 가까운 것이 가나이기 때문이고, 한글 발음이 그 아래인 것은
/// 그것이 여기까지 온 열쇠이기 때문이다.
/// 활용형이면 무엇을 되돌렸는지도 말해 준다. 낱말만 던져 주는 것과
/// "止める의 명령형"이라고 알려 주는 것은 교재로서 값이 다르다.
///
/// **카드는 문장보다 작다.** 사용자가 친 것은 문장이고 이 카드들은 그것을 뜯어본 것이라,
/// 카드가 더 크면 조각이 원본보다 세 보인다. 문장 44 에 맞춰 26 으로 내렸고,
/// 아래 층들도 함께 따라 내려 카드 안의 차례는 그대로 뒀다.
struct SegmentCard: View {
    let segment: Segment
    /// 문장에서 이 조각을 골랐는가.
    ///
    /// 고른 카드는 왼쪽에 선 하나를 세워 표시한다. 문장 쪽 강조가 이미 반전이라
    /// 여기까지 반전하면 화면에 검은 덩어리가 둘이 되어 어느 쪽이 답인지 흐려진다.
    var isSelected: Bool = false
    /// 담아 달라고 위로 알린다. **카드가 직접 담지 않는다** — 어디에 넣을지 묻는 모달은
    /// 화면에 하나여야 하는데, 카드마다 시트를 달면 조각 수만큼 생긴다.
    var onCollect: (CollectedWord) -> Void = { _ in }

    /// 다른 뜻을 펼쳐 놓았는가.
    ///
    /// **카드는 세 층이다** — 가나 · 한국어 발음 · 뜻. 대안 후보를 그 아래 늘어놓으면
    /// 카드마다 층이 넷도 되고 다섯도 되어, 훑는 눈이 매번 어디까지가 이 낱말인지 센다.
    ///
    /// 그렇다고 버릴 수도 없다. 1위가 정답일 확률은 93.8%지만 3위 안에 있을 확률은
    /// 97.8%다 — 그 4%가 사전이 헛짚었을 때 사용자가 스스로 찾아낼 유일한 길이다.
    /// **접어 두고 누르면 편다.** 기본은 세 층이고, 더 볼 사람만 한 번 더 누른다.
    @State private var expanded = false

    /// 담아 두는 곳. 갈피표가 이것을 쓴다.
    ///
    /// **넘겨받지 않고 환경에서 꺼낸다.** 예전에는 옵셔널로 받아 없으면 갈피표를
    /// 그리지 않았는데, 그 nil 분기가 이 카드를 거쳐 찾기 화면까지 붙어 있었다.
    /// 환경에 없으면 그 자리에서 멎으므로, 조립 루트가 빠뜨린 것을 바로 알게 된다.
    @Environment(CollectionStore.self) private var collection
    @Environment(TranslationDesk.self) private var desk

    private var top: SearchResult? { segment.results.first }
    /// 1위와 같은 낱말은 걸러진 채로 온다 — 大丈夫 가 두 번 보이지 않도록.
    private var alternates: [SearchResult] { segment.alternates() }

    /// 화면에 보일 뜻.
    ///
    /// **사전에 한국어 뜻이 있으면 그것이 먼저다.** 미리 구워 둔 것이라 근거가 분명하다.
    /// 없는 낱말만 영어 뜻을 옮겨서 보여 준다 — 굽기가 22,610 개까지 닿았고 그 밖은
    /// 아직 영어로 남아 있다. `activity · active` 를 그대로 보여 주느니 옮겨서 보여 준다.
    private func korean(of entry: DictEntry) -> String {
        guard entry.koreanGloss == nil else { return entry.displayGloss }
        return desk.english[entry.displayGloss] ?? entry.displayGloss
    }

    /// 이 카드에 영어로 남아 있는 뜻들. 대안 후보까지 한 번에 보낸다 —
    /// 펼쳐 볼 때 하나씩 물으면 그때마다 기다림이 보인다.
    private var untranslated: [String] {
        (segment.results.prefix(1) + alternates)
            .filter { $0.entry.koreanGloss == nil }
            .map(\.entry.displayGloss)
            .filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let top {
                headline(top)
                let gloss = korean(of: top.entry)
                if !gloss.isEmpty {
                    Text(gloss)
                        .font(Theme.korean(14))
                        .foregroundStyle(Theme.grey1)
                }
                if !alternates.isEmpty {
                    if expanded {
                        alternateList
                    } else {
                        moreButton
                    }
                }
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
        // 영어로 남은 뜻을 옮겨 달라고 보낸다. 이미 옮긴 것은 그 자리에서 걸러지므로
        // 같은 낱말이 다시 나와도 묻지 않는다.
        .task(id: segment.hangul) { desk.english.ask(untranslated) }
    }

    // MARK: 첫 번째 답

    private func headline(_ result: SearchResult) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(result.reading)
                    .font(Theme.japanese(26, weight: .medium))
                    .foregroundStyle(Theme.ink)

                // **품사.** 실제 사전이 하는 것과 같다 — 낱말마다 늘 있으므로 자리가 고정된다.
                //
                // 여기 있던 것은 활용형 되돌림 표시였다(`야메떼의 기본형`). 그것은
                // 되돌렸을 때만 떠서 카드마다 있다 없다 했고, 무엇보다 **낱말에 대해
                // 말해 주는 것이 없었다** — 이 낱말이 동사인지 명사인지가 사전에서
                // 먼저 알고 싶은 것이다. 내가 친 원문은 위 문장 머리에 그대로 있다.
                if let 품사 = result.entry.wordClass.displayName {
                    PartOfSpeechTag(name: 품사)
                }

                Spacer(minLength: 8)
                SpeakButton(text: result.reading)
                bookmark(result, in: collection)
            }

            // **한글 발음은 늘 보인다.** 한때는 다이얼로 껐다 켰는데, 층이 가나와 한글
            // 둘뿐이 되면서 끌 것이 하나밖에 남지 않았다 — 두 칸짜리 다이얼은
            // 고르는 일이 아니라 켜고 끄는 스위치이고, 그것이 끄는 것은 이 사람이
            // 낱말을 찾아온 바로 그 열쇠다.
            //
            // **되돌렸으면 되돌린 자리를 보인다.** 사전에는 사전형만 실려 있어서
            // `やめて` 를 치면 카드에는 `やめる` 가 뜬다. 그 사이를 말해 주지 않으면
            // "야메떼라고 쳤는데 왜 야메루가 나오지?"가 된다 — 만든 사람도 물었다.
            //
            // 조각의 음차만 놓아도 안 된다. 그러면 위의 가나(`やめる`)와 다른 낱말의
            // 소리가 되어 "야메떼가 やめる 라고 읽히나?"가 된다.
            //
            // **둘을 화살표로 잇는다.** 내가 친 소리에서 이 낱말의 소리로 건너간 것이
            // 한 줄에 다 보인다. 되돌리지 않았으면 화살표 없이 소리 하나뿐이다.
            reading(result)
        }
    }

    /// 소리 줄. 되돌렸으면 `야메떼 → 야메루`, 아니면 `쿠다사이`.
    @ViewBuilder
    private func reading(_ result: SearchResult) -> some View {
        let sound = KanaToHangul.transliterate(result.reading)
        if result.deinflection != nil, segment.hangul != sound {
            HStack(spacing: 6) {
                Text(segment.hangul)
                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .medium))
                Text(sound)
            }
            .font(Theme.korean(14))
            .foregroundStyle(Theme.grey3)
        } else {
            Text(sound)
                .font(Theme.korean(14))
                .foregroundStyle(Theme.grey3)
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
                                 gloss: korean(of: result.entry),
                                 partOfSpeech: result.entry.wordClass.displayName)
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

    /// 대안 후보는 **뜻만** 늘어놓는다.
    ///
    /// 한때는 가나를 앞에 붙였는데, 한자를 뺀 뒤로 그 가나가 **첫 줄과 똑같아졌다** —
    /// `やめる` 를 찾으면 `やめる 멈추다` · `やめる 퇴사하다` · `やめる sick` 이 되어
    /// 같은 글자가 세 번 나온다. 대안끼리 가르는 것이 이제 뜻뿐이므로 가나는 정보가 0이다.
    ///
    /// **그리고 층을 깼다.** 카드의 규칙은 가나 · 한국어 발음 · 뜻 세 층인데,
    /// 대안만 "가나 + 뜻" 한 줄이라 같은 카드 안에서 문법이 둘로 갈렸다.
    /// 뜻만 남기면 위의 뜻 줄에 그대로 이어져 **한 층이 여러 줄인 것**으로 읽힌다.
    /// 접혀 있을 때의 한 줄. **개수를 적는다** — 몇 개가 더 있는지 알아야 누를지 정한다.
    ///
    /// 글자를 회색으로만 두고 꼬리표나 테두리를 붙이지 않는다. 이 카드에서 눌러야 하는
    /// 것은 갈피표와 소리이고, 이것은 "더 있다"는 표시일 뿐이라 그 둘과 무게를 겨루면 안 된다.
    private var moreButton: some View {
        Button {
            withAnimation(.snappy(duration: 0.18)) { expanded = true }
        } label: {
            HStack(spacing: 5) {
                Text("다른 뜻 \(alternates.count)")
                    .font(Theme.korean(12))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .medium))
            }
            .foregroundStyle(Theme.grey3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var alternateList: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(alternates.enumerated()), id: \.offset) { _, result in
                Text(korean(of: result.entry))
                    .font(Theme.korean(12))
                    .foregroundStyle(Theme.grey2)
                    .lineLimit(1)
            }
            Button {
                withAnimation(.snappy(duration: 0.18)) { expanded = false }
            } label: {
                Text("접기")
                    .font(Theme.korean(12))
                    .foregroundStyle(Theme.grey3)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
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
