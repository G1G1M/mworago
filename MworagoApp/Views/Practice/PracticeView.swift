import SwiftUI
import MworagoCore

/// 연습 — 모은 낱말을 **가나만 보고** 떠올려 본다.
///
/// 기획의 목적지는 쉐도잉(소리 내어 따라 하고 얼마나 닮았는지 보기)이고 그것은 v2.0 이다.
/// 지금 가진 재료로 할 수 있는 것은 **모은 것을 다시 만나는 일**이다 —
/// 가나를 먼저 보이고, 떠올린 다음 뒤집어 확인한다.
///
/// **한글 음차를 앞에 두지 않는다.** 그것은 찾을 때 쓰는 열쇠이지 익힐 것이 아니다.
/// 앞에 두면 한글 음차를 보고 뜻을 떠올리는 연습이 되는데, 목적지는 자막 없이
/// 알아듣는 것이고 자막에 뜨는 것은 가나다. 다만 뒤에는 남긴다 —
/// 어떻게 찾았는지의 기록이자 소리와 글자를 잇는 다리라서, 답의 일부지 문제가 아니다.
///
/// 채점하지 않는다. 맞혔는지 틀렸는지 기록하기 시작하면 점수를 관리하는 앱이 되는데,
/// 여기서 하려는 일은 **다시 마주치게 하는 것**뿐이다.
struct PracticeView: View {
    @Environment(CollectionStore.self) private var collection
    /// 한자의 한국 독음. 상세 시트가 이미 한 번 읽어 둔 것을 나눠 쓴다.
    /// 교재에서 하루치만 들고 건너왔을 때 그 낱말들. 비어 있으면 모은 것 전체를 훑는다.
    ///
    /// **늘 전체를 훑으면 오늘 본 것을 다시 만나기까지 한참이 걸린다.** 스무 날치가
    /// 쌓인 뒤에는 더 그렇다. 어느 화를 복습할지는 사용자가 교재에서 고른다.
    var subset: [CollectedWord]? = nil
    var subsetLabel: String? = nil
    /// 하루치에서 빠져나와 전체로 돌아간다.
    var onClearSubset: () -> Void = {}

    /// 지금 보고 있는 낱말. **`id` 로 들고 있다** — 자리(번호)로 들면 하루치를 바꾸거나
    /// 낱말을 뺐을 때 같은 번호가 딴 낱말을 가리킨다.
    @State private var currentID: CollectedWord.ID?
    /// `--revealed` 로 뒤집힌 채 띄운다. `--query=` · `--detail` 과 같은 취지 —
    /// 시뮬레이터는 손으로 두드릴 수 없어 뒷면을 눈으로 볼 길이 없다.
    @State private var revealed = LaunchOptions.current.has("revealed")
    ///
    /// **막히는 자리에 두어야 닿는다.** 가나를 못 읽어서 멈추는 순간은 여기서 생긴다 —
    /// 앞면이 소리뿐이라 읽을 수 없으면 뒤집기 말고는 할 것이 없다. 설정에 넣으면
    /// 그 순간에 떠올릴 수 없는 자리가 된다. `--kana` 로 펼친 채 띄운다.

    private var words: [CollectedWord] { subset ?? collection.words }
    private var current: CollectedWord? {
        words.first { $0.id == currentID } ?? words.first
    }
    /// 몇 번째 장인가. 보고 있던 낱말이 사라졌으면 첫 장으로 친다.
    private var index: Int {
        words.firstIndex { $0.id == currentID } ?? 0
    }

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            if words.isEmpty {
                empty
            } else {
                // **손으로 밀어도 넘어간다.** 카드 더미를 넘기는 몸짓이 단추보다 먼저
                // 떠오르는 자리다. 단추는 그대로 둔다 — 밀 수 있다는 것은 해 봐야 알고,
                // `이전`·`다음` 은 보이는 채로 있다.
                Pager(items: words, current: $currentID) { word in
                    card(word)
                        // 카드가 화면 한가운데 선다. 페이지가 뷰포트 높이를 그대로 받고,
                        // 그 안에서 카드는 제 크기대로 가운데 놓인다.
                        .containerRelativeFrame(.vertical)
                }
            }
            if let subsetLabel { subsetBanner(subsetLabel) }
        }
        // 첫 장. 담긴 것이 없다가 생겼을 때도 여기서 잡힌다.
        //
        // **`current` 로 묻지 않는다.** 그것은 못 찾으면 첫 낱말을 내주므로 목록이
        // 비지 않는 한 `nil` 이 아니고, 그러면 `currentID` 는 영영 비어 있게 된다 —
        // 화면은 첫 장을 보여 주는데 넘긴 자리를 아무도 들고 있지 않은 꼴이다.
        .onAppear {
            if words.first(where: { $0.id == currentID }) == nil {
                currentID = words.first?.id
            }
        }
        // 하루치를 새로 골라 오면 처음 낱말부터 시작한다.
        .onChange(of: subsetLabel) { _, _ in
            currentID = words.first?.id
            revealed = false
        }
        // **장이 바뀌면 도로 덮인다.** 밀어서 넘겼든 단추로 넘겼든 같다 —
        // 다음 낱말의 답이 이미 펼쳐져 있으면 떠올려 볼 틈이 없다.
        .onChange(of: currentID) { _, _ in revealed = false }
    }

    /// 지금 무엇을 연습하고 있는지. 전체가 아니라면 그 사실이 화면에 있어야 한다 —
    /// 몇 장 넘기다 보면 어디서 온 묶음인지 잊는다.
    private func subsetBanner(_ label: String) -> some View {
        VStack {
            HStack(spacing: 10) {
                Text(label)
                    .font(Theme.korean(13, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text("\(words.count)개")
                    .font(Theme.korean(13))
                    .foregroundStyle(Theme.grey2)
                Button(action: onClearSubset) {
                    Text("전체")
                        .font(Theme.korean(13))
                        .foregroundStyle(Theme.grey2)
                }
                .buttonStyle(.plain)
                .accessibilityHint("모은 낱말 전체를 연습합니다")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.grey3.opacity(0.5), lineWidth: 0.5))
            .padding(.top, 14)
            Spacer()
        }
    }

    /// 한 장.
    ///
    /// **덩어리는 가운데, 글줄은 왼쪽.** 이름·낱말·답이 저마다 가운데로 서면 줄마다
    /// 시작하는 자리가 달라 눈이 매번 첫 글자를 찾아야 한다. 한 자리에서 시작하되,
    /// 그 덩어리를 **폭에 맞춰 재서** 화면 가운데 세운다 — 폭을 넓게 잡아 두고 그 안에서
    /// 왼쪽에 붙이면 글은 여전히 화면 왼쪽에 쏠린다.
    ///
    /// **단추 줄만 따로 가운데다.** 그것은 읽는 것이 아니라 누르는 것이고,
    /// 세 알약이 좌우로 균형을 이룰 때 손이 어디로 갈지가 분명하다.
    private func card(_ word: CollectedWord) -> some View {
        VStack(spacing: 0) {
            upper(word)
            buttons
        }
        .frame(maxWidth: Theme.readWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.gutter)
    }

    /// 읽는 것들 — 이름·낱말·답. 왼쪽에서 시작하고, 덩어리째 가운데로 간다.
    private func upper(_ word: CollectedWord) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("연습")
                    .font(Theme.korean(24, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("\(min(index + 1, words.count)) / \(words.count)")
                    .font(Theme.korean(15))
                    .foregroundStyle(Theme.grey2)
            }
            .padding(.bottom, 40)

            // **가나부터 보인다.** 한글 음차는 찾을 때 쓰는 열쇠이지 익힐 것이 아니다.
            // 그것을 앞에 두면 한글 음차를 보고 뜻을 떠올리는 연습이 되는데,
            // 자막에 뜨는 것은 `いたい` 이지 `이타이` 가 아니다.
            // 앞면에도 소리를 둔다. **뒤집기 전에 들어 보는 것이 곧 문제다** —
            // 자막에서 만나는 것은 글자만이 아니라 소리이기도 하다.
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(word.reading)
                    .font(Theme.japanese(38, weight: .medium))
                    .foregroundStyle(Theme.ink)
                marks(word)
            }

            // 뒤집기 전에는 자리만 잡아 둔다. 답이 나타나며 아래가 밀리면
            // 눈이 따라가야 해서, 있던 자리에 그대로 나타나게 한다.
            //
            // 층의 차례는 화면 어디서나 같다 — 가나(앞면) · 한글 · 뜻.
            // 한글 음차를 뒤에 남기는 것은 **"내가 이것을 어떻게 찾았는지"의 기록**이라서다.
            // 소리와 글자를 잇는 다리인데, 답의 일부지 문제는 아니다.
            VStack(alignment: .leading, spacing: 7) {
                Text(word.hangul)
                    .font(Theme.korean(15))
                    .foregroundStyle(Theme.grey3)
                if !word.gloss.isEmpty {
                    Text(word.gloss)
                        .font(Theme.korean(17))
                        .foregroundStyle(Theme.grey1)
                        .padding(.top, 4)
                }
            }
            // 폭을 넓게 잡지 않는다. `maxWidth: .infinity` 를 주면 이 줄이 카드 폭을
            // 끝까지 벌려, 덩어리를 재서 가운데 세우려던 것이 도로 왼쪽에 붙는다.
            .frame(minHeight: 130, alignment: .topLeading)
            .opacity(revealed ? 1 : 0)
            .padding(.top, 22)
        }
    }

    /// 누르는 것들. 읽는 덩어리와 달리 **줄째 가운데** 선다.
    private var buttons: some View {
        HStack(spacing: 10) {
            // 되돌아갈 길이 있어야 한다. 한 장 지나쳐 버렸을 때 스무 장을 다시
            // 넘겨 돌아오게 두지 않는다 — 온보딩의 `이전` 과 같은 이유다.
            button("이전", filled: false) { previous() }
            button(revealed ? "다시 덮기" : "뒤집기", filled: !revealed) {
                withAnimation(.snappy(duration: 0.18)) { revealed.toggle() }
            }
            button("다음", filled: revealed) { next() }
        }
        .padding(.top, 26)
    }

    /// 낱말 옆에 붙는 것들 — 품사와 소리.
    ///
    /// **품사는 앞면에 둔다.** 답이 아니라 문제의 일부다 — 동사인지 명사인지를 알고
    /// 뜻을 떠올리는 것이 실제로 하는 일이다. 소리도 마찬가지로, 뒤집기 전에
    /// 들어 보는 것이 곧 문제다.
    @ViewBuilder
    private func marks(_ word: CollectedWord) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            if let 품사 = word.partOfSpeech { PartOfSpeechTag(name: 품사) }
            SpeakButton(text: word.reading, size: 18)
        }
    }

    /// 강조는 반전 하나로만 — 지금 눌러야 하는 것이 채워진다.
    private func button(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.korean(15, weight: filled ? .semibold : .regular))
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(filled ? Theme.ink : Theme.grey4, in: Capsule())
                .foregroundStyle(filled ? Theme.paper : Theme.grey1)
        }
        .buttonStyle(.plain)
    }

    /// 한 장 앞으로. 끝에서 누르면 처음으로 돈다.
    private func next() { go(to: index + 1) }

    /// 한 장 뒤로. 첫 장에서 누르면 마지막 장으로 돌아간다 — `다음` 이 끝에서
    /// 처음으로 도는 것과 짝을 맞춘다.
    private func previous() { go(to: index - 1) }

    /// 단추로 넘길 때. 미는 손과 같은 자리로 가야 하므로 **보고 있는 낱말을 바꾸고**,
    /// 페이지는 그것을 따라 미끄러진다. 뒤집힌 것을 도로 덮는 일은 `currentID` 가
    /// 바뀔 때 한꺼번에 한다 — 밀어서 넘겼을 때와 같은 자리에서 처리해야 어긋나지 않는다.
    private func go(to position: Int) {
        guard !words.isEmpty else { return }
        let wrapped = (position % words.count + words.count) % words.count
        withAnimation(.snappy(duration: 0.18)) { currentID = words[wrapped].id }
    }

    /// 연습할 것이 없을 때. 화면 한가운데 서고 글줄은 왼쪽에서 시작한다 —
    /// 책장의 빈 화면과 같은 꼴이라 탭을 옮겨도 같은 말을 같은 자리에서 만난다.
    ///
    /// 좌우 여백을 폭 **안쪽**에 둔다. 폭을 잰 뒤에 붙이면 덩어리가
    /// `readWidth + 여백` 이 되어 재 둔 폭이 실제와 어긋난다.
    private var empty: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("연습할 것이 없어요")
                .font(Theme.korean(22, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("모은 낱말을 가나만 보고 떠올려 보는 자리입니다.")
                .font(Theme.korean(15))
                .foregroundStyle(Theme.grey2)
            Text("소리 내어 따라 하고 얼마나 닮았는지 보는 것은 그다음이에요.")
                .font(Theme.korean(13))
                .foregroundStyle(Theme.grey3)
        }
        .padding(.horizontal, Theme.gutter)
        .frame(maxWidth: Theme.readWidth, alignment: .leading)
        // 글은 왼쪽에서 시작하되 **덩어리는 화면 가운데 선다.** 아이패드처럼 넓은 화면에서
        // 폭만 묶어 두면 덩어리가 왼쪽에 붙어, 오른쪽이 통째로 비어 보인다.
        .frame(maxWidth: .infinity)
        // 첫 줄을 책장의 빈 화면과 같은 높이에 세운다 — 자세한 까닭은 `emptyBlockHeight`.
        .frame(minHeight: Theme.emptyBlockHeight, alignment: .topLeading)
        // `ZStack` 안이라 이것 없이도 가운데로 오지만, 책장의 빈 화면과 **같은 문법**으로
        // 세워 둔다. 기준이 다르면 한쪽만 손댔을 때 두 화면이 소리 없이 어긋난다.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
