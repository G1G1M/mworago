import SwiftUI
import MworagoCore

/// 익히기 — 랜덤으로 나온 글자의 소리를 떠올리고 뒤집어 확인한다.
///
/// **채점하지 않는다.** 낱말 연습과 같은 규칙이다 — 맞고 틀림을 세기 시작하면
/// 점수를 관리하는 앱이 되는데, 여기서 하려는 일은 마흔여섯 자를 **여러 번 마주치게
/// 하는 것**뿐이다. 처음에는 거의 못 읽을 텐데 그때 점수가 남으면 그 화면이 곧 좌절이 된다.
struct KanaQuiz: View {
    enum Scope: Int, CaseIterable, Identifiable {
        case hiragana, katakana, both
        var id: Int { rawValue }
        var label: String {
            switch self {
            case .hiragana: "히라가나"
            case .katakana: "가타카나"
            case .both: "둘 다"
            }
        }
    }

    /// 무슨 차례로 물을까.
    ///
    /// **랜덤만 있으면 훑었는지 알 수 없다.** 마흔여섯 자를 다 만났는지, 같은 것만
    /// 세 번 나온 것인지 셀 방법이 없다. 순서대로는 표의 차례(あ か さ…)를 그대로
    /// 따라가므로 어디까지 왔는지가 곧 얼마나 남았는지다.
    enum Order: Int, CaseIterable, Identifiable {
        case inOrder, random
        var id: Int { rawValue }
        var label: String {
            switch self {
            case .inOrder: "순서대로"
            case .random: "랜덤"
            }
        }
    }

    /// 물을 것 하나 — **소리 하나와, 그것을 어느 글자로 보일지의 짝.**
    ///
    /// 한때는 소리만 늘어놓고 히라가나로 보일지 가타카나로 보일지는 넘길 때마다
    /// 동전을 던졌다. 그래서 범위를 무엇으로 골라도 차례가 107 로 끝났고 —
    /// 다이얼이 장수를 바꾸는 것처럼 보이는데 숫자는 그대로였다 — 한 판에서
    /// `あ` 는 봤는데 `ア` 는 한 번도 안 나오기도 했다.
    ///
    /// **익힐 것은 소리가 아니라 글자다.** `あ` 와 `ア` 는 따로 외워야 하므로 따로 센다.
    struct Card: Equatable, Identifiable {
        let kana: String
        let katakana: Bool
        /// 앞면에 보이는 글자. 뒤집기 전에는 이것 하나뿐이다.
        var shown: String { katakana ? KanaTable.toKatakana(kana) : kana }
        /// `あ` 와 `ア` 는 따로 외우는 글자라 따로 센다 — 자리도 따로다.
        var id: String { (katakana ? "K" : "H") + kana }
    }

    @State private var scope: Scope = .hiragana
    @State private var order: Order = .random
    /// 이번 판에 물을 차례. 범위와 순서가 바뀌면 다시 짠다 —
    /// **범위 셋이 각자 제 차례를 갖는다.**
    @State private var deck: [Card] = KanaQuiz.cards(scope: .hiragana, order: .random)
    /// 지금 보고 있는 장. **자리(번호)가 아니라 `id` 로 붙든다** — 밀어서 넘길 때
    /// 스크롤이 돌려주는 것이 자리가 아니라 장 자체이기 때문이다(연습 카드와 같다).
    @State private var currentID: Card.ID?
    @State private var revealed = LaunchOptions.current.has("revealed")

    /// 표에 실린 소리 전부. 빈 자리(ゐ·ゑ)는 뺀다 — 표에서는 자리를 지켜야 행과 단이
    /// 맞지만, 여기서는 안 쓰는 소리를 물을 이유가 없다.
    private static let pool: [String] = KanaTable.ordered

    /// 범위와 순서로 이번 판의 차례를 짠다.
    ///
    /// **"둘 다"는 히라가나 한 바퀴를 돈 뒤에 가타카나 한 바퀴다.** `あ` 다음에 바로
    /// `ア` 를 두면 방금 본 답이 그대로 답이라 물어볼 것이 없다 — 표에서 같은 소리의
    /// 두 글자를 나란히 놓지 않는 것과 같은 이유다.
    private static func cards(scope: Scope, order: Order) -> [Card] {
        let hiragana = pool.map { Card(kana: $0, katakana: false) }
        let katakana = pool.map { Card(kana: $0, katakana: true) }
        let cards: [Card] = switch scope {
        case .hiragana: hiragana
        case .katakana: katakana
        case .both: hiragana + katakana
        }
        return order == .random ? cards.shuffled() : cards
    }

    /// 지금 물고 있는 것. **차례에서 꺼내 온다** — 따로 들고 있으면 범위를 좁혔을 때
    /// 지난 판의 글자가 남는다.
    private var current: Card {
        deck.first { $0.id == currentID } ?? deck.first ?? Card(kana: "あ", katakana: false)
    }

    /// 몇째 장인가.
    private var at: Int { deck.firstIndex { $0.id == currentID } ?? 0 }

    /// **이 화면만 가운데 맞춤이다.**
    ///
    /// 앱의 다른 화면은 왼쪽에서 시작한다 — 글줄이 여럿이면 시작점이 같아야 눈이 다음 줄을
    /// 찾기 때문이다. 그런데 여기 놓이는 것은 글줄이 아니라 **마주보는 글자 하나**다.
    /// 읽어 내려가는 화면이 아니라 한 글자를 들여다보는 화면이라, 왼쪽에 붙여 두면
    /// 넓은 여백 한쪽에 작은 것이 치우쳐 매달린다. 아이패드에서 특히 그렇다.
    ///
    /// 다이얼도 버튼도 같은 축에 세운다. 글자만 가운데고 나머지가 왼쪽에 붙으면
    /// 축이 둘이 되어 어긋난 것이 더 크게 보인다.
    var body: some View {
        VStack(spacing: 0) {
            // 범위 · 순서 · 초기화. 셋 다 "무엇을 물을까"를 정하는 것이지만
            // **무게가 같으면 안 된다.**
            //
            // 한때는 다섯이 다 같은 캡슐이었다. 그러면 "고르는 것"과 "하는 것"이 같은
            // 옷을 입는다 — 초기화는 선택지가 아니라 동작인데 나머지 넷과 나란히
            // 앉아 있어, 무엇이 지금 켜져 있는지 세어 봐야 알 수 있었다.
            //
            // 범위가 가장 큰 결정이라 가장 무겁고(캡슐), 순서는 같은 문법이되 한 단계
            // 작으며, 초기화는 **배경을 벗는다.** 책장의 `이 묶음 연습` 이 이미 쓰는
            // 문법이라 새로 배울 것이 없다.
            VStack(spacing: 10) {
                scopeDial
                // 순서 다이얼과 초기화 사이에 세로선을 세웠다가 **걷어냈다.**
                // `Divider` 에 여백을 먼저 주고 그 위에 색을 덮어서, 선이 아니라
                // 여백까지 통째로 칠해진 회색 네모(49×14)가 그려졌다.
                // 둘은 크기와 배경으로 이미 갈린다 — 하나는 채워지는 알약이고
                // 하나는 배경이 없다. 선을 다시 세울 이유가 없다.
                HStack(spacing: 16) {
                    orderDial
                    Button { reset() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10, weight: .medium))
                            Text("초기화")
                                .font(Theme.korean(.sub))
                        }
                        .foregroundStyle(Theme.grey2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                // 몇째까지 왔는가. **순서대로일 때만 뜻이 있다** — 섞인 차례에서
                // "12/46"은 남은 것이 무엇인지 말해 주지 않는다.
                if order == .inOrder {
                    Text("\(at + 1) / \(deck.count)")
                        .font(Theme.korean(.tag))
                        .foregroundStyle(Theme.grey3)
                        .monospacedDigit()
                }
            }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, Theme.screenTop)

            // **손으로 밀어도 넘어간다.** 연습 카드와 같은 몸짓이다 — 넘기는 일 자체는
            // 시스템에 맡기고(`Pager`), 단추는 그대로 둔다. 밀 수 있다는 것은 해 봐야 안다.
            // **손으로 밀지 않는다.** 바깥(글자 탭)이 가로로 미는 일을 이미 맡고 있다 —
            // 표와 익히기 사이를 오가는 일이다. 한 화면에서 가로 축이 두 가지를 뜻하면
            // 안쪽이 손을 먹어 버려 표로 돌아올 길이 막힌다. 넘기는 것은 `이전`·`다음`
            // 이 하고, 자리가 바뀔 때 미끄러지는 것은 그대로다.
            Pager(items: deck, current: $currentID, scrollDisabled: true) { item in
                KanaQuizCard(item: item, revealed: revealed)
                    .frame(maxHeight: .infinity)
            }

            FlipControls(revealed: $revealed, size: .large,
                         onPrevious: previous, onNext: next)
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, Theme.screenBottom)
        }
        .frame(maxWidth: .infinity)
        // 연습 카드와 같은 결로 알린다. 두 화면이 하는 일이 같으므로 손끝도 같아야 한다.
        .sensoryFeedback(.selection, trigger: revealed)
        // 첫 장. 범위를 바꿔 차례를 다시 짰을 때도 여기서 잡힌다.
        .onAppear { if current.id != currentID { currentID = deck.first?.id } }
        // **장이 바뀌면 도로 덮인다.** 밀어서 넘겼든 단추로 넘겼든 같다.
        // 첫 장을 잡을 때는 덮지 않는다 — `--revealed` 로 펼친 채 띄우는 길이 있다.
        .onChange(of: currentID) { 앞, _ in if 앞 != nil { revealed = false } }
    }

    /// 순서 다이얼. 범위 다이얼과 같은 문법이다 — 평평하고, 고른 것 하나만 검게 채워진다.
    private var orderDial: some View {
        HStack(spacing: 5) {
            ForEach(Order.allCases) { option in
                // 범위 다이얼과 같은 문법이되 **한 단계 작다.** 같은 일을 하지만
                // 덜 중요한 결정이라는 것이 크기로 드러난다.
                ChoiceChip(title: option.label, isSelected: option == order, size: .tag) {
                    order = option
                    reset()
                }
            }
        }
    }

    private var scopeDial: some View {
        HStack(spacing: 7) {
            ForEach(Scope.allCases) { option in
                ChoiceChip(title: option.label, isSelected: option == scope) {
                    withAnimation(.snappy(duration: 0.18)) {
                        scope = option
                        reset()
                    }
                }
            }
        }
    }

    /// 다음 글자. **짠 차례를 따라간다** — 끝에 닿으면 처음으로 돌아간다.
    ///
    /// 한때는 매번 무작위로 뽑고 같은 글자만 피했다. 그러면 마흔여섯 자를 다 만났는지
    /// 알 수 없고, 운이 나쁘면 몇 자를 영영 못 본다.
    private func next() {
        guard !deck.isEmpty else { return }
        withAnimation(.snappy(duration: 0.18)) {
            currentID = deck[(at + 1) % deck.count].id
        }
    }

    /// 한 장 뒤로. 첫 장에서 누르면 마지막 장으로 돌아간다 — `다음` 과 짝을 맞춘다.
    private func previous() {
        guard !deck.isEmpty else { return }
        withAnimation(.snappy(duration: 0.18)) {
            currentID = deck[(at - 1 + deck.count) % deck.count].id
        }
    }

    /// 처음으로. **랜덤이면 다시 섞는다** — 초기화가 같은 차례를 되풀이하면
    /// 무작위라고 할 수 없다.
    private func reset() {
        withAnimation(.snappy(duration: 0.18)) {
            deck = Self.cards(scope: scope, order: order)
            currentID = deck.first?.id
            revealed = false
        }
    }
}
