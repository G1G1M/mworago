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
                // **미는 것은 카드뿐이다.**
                //
                // 한때는 머리줄과 단추까지 한 장에 담아 통째로 밀었다. 그런데 저 둘은
                // 장에 딸린 것이 아니라 **화면에 딸린 것**이다 — 스무 장을 넘겨도 `뒤집기`
                // 는 같은 자리에 있어야 손이 그 자리를 기억한다. 머리줄도 장마다 같은
                // 말("연습")을 다시 적으므로, 밀 때마다 같은 글자가 옆에서 흘러들어와
                // 넘어간 것이 아니라 화면이 흔들린 것처럼 보였다.
                VStack(spacing: 0) {
                    header
                    // **카드와 단추가 한 덩어리로 가운데 선다.**
                    //
                    // 한때는 카드 자리가 남은 높이를 통째로 먹었다. 카드는 그 안에서
                    // 가운데 서고 단추는 화면 바닥에 붙으니, 아이패드에서 둘 사이가
                    // 500pt 넘게 벌어졌다 — 뒤집을 것과 뒤집는 단추가 서로 남남으로 보인다.
                    // 눈이 카드에서 단추로 가는 길이 화면 절반이었다.
                    //
                    // 카드가 설 자리를 정해 주고, 남는 높이는 위아래 빈자리가 나눠 갖는다.
                    Spacer(minLength: 0)
                    Pager(items: words, current: $currentID) { word in
                        card(word)
                            // 정해 준 자리 안에서 카드가 가운데 선다.
                            .frame(maxHeight: .infinity)
                    }
                    .frame(height: cardArea)
                    buttons
                    Spacer(minLength: 0)
                }
                .padding(.top, Theme.screenTop)
                .padding(.bottom, Theme.screenBottom)
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
        //
        // **첫 장을 잡을 때는 덮지 않는다.** 화면이 서면서 `currentID` 가 `nil` 에서
        // 첫 낱말로 한 번 바뀌는데, 그것까지 "장이 바뀐 것"으로 세면 `--revealed` 로
        // 펼친 채 띄우는 길이 막힌다(글자 익히기는 이미 막아 둔 자리다).
        .onChange(of: currentID) { 앞, _ in if 앞 != nil { revealed = false } }
    }

    /// 지금 무엇을 연습하고 있는지. 전체가 아니라면 그 사실이 화면에 있어야 한다 —
    /// 몇 장 넘기다 보면 어디서 온 묶음인지 잊는다.
    private func subsetBanner(_ label: String) -> some View {
        VStack {
            HStack(spacing: 10) {
                Text(label)
                    .font(Theme.korean(.sub, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text("\(words.count)개")
                    .font(Theme.korean(.sub))
                    .foregroundStyle(Theme.grey2)
                Button(action: onClearSubset) {
                    Text("전체")
                        .font(Theme.korean(.sub))
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

    /// 지금 어디쯤인가. **장을 따라 밀리지 않는다** — 장마다 같은 말을 다시 적는 줄이라,
    /// 밀 때 같은 글자가 옆에서 흘러들어오면 넘어간 것이 아니라 화면이 흔들려 보인다.
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("연습")
                .font(Theme.korean(.heading, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("\(min(index + 1, words.count)) / \(words.count)")
                .font(Theme.korean(.body))
                .foregroundStyle(Theme.grey2)
                .monospacedDigit()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: Theme.readWidth, alignment: .leading)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.gutter)
    }

    /// 한 장. **앞뒤가 있는 카드다.**
    ///
    /// 앞면은 문제 — 가나와, 그것을 읽는 데 쓰는 것들(품사·소리). 뒷면은 답 —
    /// 한글 음차와 뜻. 뒷면에도 가나를 작게 남긴다. 뒤집고 나서 "무엇의 답인지"를
    /// 다시 찾아 앞면으로 되돌아가게 하지 않기 위해서다.
    ///
    /// **덩어리는 가운데, 글줄은 왼쪽.** 줄마다 시작점이 다르면 눈이 매번 첫 글자를
    /// 찾아야 한다. 한 자리에서 시작하되 그 덩어리를 폭에 맞춰 재서 화면 가운데 세운다.
    private func card(_ word: CollectedWord) -> some View {
        FlipCard(angle: revealed ? 180 : 0) {
            face { question(word) }
        } back: {
            face { answer(word) }
        }
        .frame(maxWidth: Theme.readWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.gutter)
    }

    /// 카드의 면 하나. **앞뒤가 같은 판 위에 있어야** 뒤집는 것이 한 물건으로 읽힌다.
    /// 글자 익히기 카드와 같은 꼴이다 — 두 화면이 하는 일이 같으므로 물건도 같아야 한다.
    private func face<V: View>(@ViewBuilder _ inner: () -> V) -> some View {
        inner()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 26)
            .padding(.vertical, 34)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Theme.grey3.opacity(0.45), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 10, y: 3)
    }

    /// 앞면 — 문제.
    ///
    /// **가나부터 보인다.** 한글 음차는 찾을 때 쓰는 열쇠이지 익힐 것이 아니다.
    /// 그것을 앞에 두면 한글 음차를 보고 뜻을 떠올리는 연습이 되는데, 자막에 뜨는 것은
    /// `いたい` 이지 `이타이` 가 아니다.
    ///
    /// **품사와 소리는 앞면에 둔다.** 답이 아니라 문제의 일부다 — 동사인지 명사인지를
    /// 알고 뜻을 떠올리는 것이 실제로 하는 일이고, 뒤집기 전에 들어 보는 것이 곧 문제다.
    private func question(_ word: CollectedWord) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(word.reading)
                .font(Theme.japanese(.display, weight: .medium))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            marks(word)
        }
        .frame(minHeight: Self.faceHeight, alignment: .leading)
    }

    /// 뒷면 — 답.
    ///
    /// 층의 차례는 화면 어디서나 같다 — 가나 · 한글 · 뜻. 한글 음차를 남기는 것은
    /// **"내가 이것을 어떻게 찾았는지"의 기록**이라서다. 소리와 글자를 잇는 다리인데,
    /// 답의 일부지 문제는 아니다.
    private func answer(_ word: CollectedWord) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            // 무엇의 답인지. 앞면보다 작게 두어 답과 섞이지 않는다.
            //
            // **한자는 뒷면에만 단다.** 앞면은 문제이고 한자는 뜻을 반쯤 알려 준다 —
            // `病める` 를 보여 주고 뜻을 맞혀 보라는 것은 연습이 아니다.
            // 뒤집은 뒤에는 "그 낱말이 이것이었다"는 정보라 답의 일부다.
            Headword(reading: word.reading, kanji: word.kanji,
                     size: .heading, weight: .regular, tint: Theme.grey2)
            Text(word.hangul)
                .font(Theme.korean(.body))
                .foregroundStyle(Theme.grey3)
            if !word.gloss.isEmpty {
                Text(word.gloss)
                    .font(Theme.korean(.heading))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
            SpeakButton(text: word.reading, size: 18)
                .padding(.top, 8)
        }
        .frame(minHeight: Self.faceHeight, alignment: .leading)
    }

    /// 두 면이 함께 쓰는 최소 높이. **앞뒤가 크게 다르면 뒤집는 순간 카드가 늘었다
    /// 줄었다 한다** — 겹쳐 두었으므로 높이는 큰 쪽으로 굳지만, 바닥값을 함께 두어야
    /// 짧은 낱말과 긴 낱말 사이에서도 카드가 들썩이지 않는다.
    private static let faceHeight: CGFloat = 150

    /// 카드가 설 자리의 높이.
    ///
    /// **높이를 정해 주는 것은 넘길 때 단추가 안 움직이게 하기 위해서다.** 장들은
    /// 필요할 때 만들어지는데(`LazyHStack`), 자리를 카드 크기에 맡기면 뜻이 긴 장이
    /// 들어오는 순간 자리가 늘고 아래 단추가 밀린다. 스무 장을 넘겨도 `뒤집기` 는
    /// 같은 자리에 있어야 손이 그 자리를 기억한다.
    ///
    /// 글자 크기를 키우면 함께 자란다 — 값을 고정하면 키운 사람에게만 카드가 잘린다.
    @ScaledMetric private var cardArea: CGFloat = 300

    /// 누르는 것들. 읽는 덩어리와 달리 **줄째 가운데** 선다.
    private var buttons: some View {
        HStack(spacing: 10) {
            // 되돌아갈 길이 있어야 한다. 한 장 지나쳐 버렸을 때 스무 장을 다시
            // 넘겨 돌아오게 두지 않는다 — 온보딩의 `이전` 과 같은 이유다.
            // **검게 채우는 것은 가운데 하나뿐이다.** 이 화면에서 하는 일은 뒤집는
            // 것이고, `이전`·`다음` 은 그 일을 하고 나서 자리를 옮기는 것이다.
            // 뒤집을 때마다 `다음` 이 검어지면 셋 중 무엇이 지금 할 일인지가 흐려지고,
            // 화면이 "다음으로 가라"고 재촉하는 것처럼 읽힌다.
            button("이전", filled: false) { previous() }
            button(revealed ? "다시 덮기" : "뒤집기", filled: true) {
                withAnimation(Flip.motion) { revealed.toggle() }
            }
            button("다음", filled: false) { next() }
        }
        .frame(maxWidth: .infinity)
        // 뒤집는 것이 이 화면에서 하는 일이다. 카드가 넘어가는 결로 한 번 알린다 —
        // 답을 맞혔는지 틀렸는지를 말하지 않으므로 성공·실패의 결은 쓰지 않는다.
        .sensoryFeedback(.selection, trigger: revealed)
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
                .font(Theme.korean(.body, weight: filled ? .semibold : .regular))
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
                .font(Theme.korean(.heading, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("모은 낱말을 가나만 보고 떠올려 보는 자리입니다.")
                .font(Theme.korean(.body))
                .foregroundStyle(Theme.grey2)
            Text("소리 내어 따라 하고 얼마나 닮았는지 보는 것은 그다음이에요.")
                .font(Theme.korean(.sub))
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
