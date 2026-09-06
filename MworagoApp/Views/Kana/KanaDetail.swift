import SwiftUI
import MworagoCore

/// 글자 하나 — 시트에 실어 보내려면 무엇으로 식별되는지가 있어야 한다. 글자가 곧 그것이다.
///
/// 표에서도 쓰고(어느 칸을 눌렀는가) 상세에서도 쓴다(지금 어느 장을 보고 있는가).
struct Glyph: Identifiable {
    let kana: String
    var id: String { kana }

    /// 표를 읽는 차례 그대로 늘어선 글자 전부. 넘겨 보는 차례가 이것이다.
    static let all: [Glyph] = KanaTable.ordered.map(Glyph.init)
}

/// 글자 하나.
///
/// 표는 훑는 곳이라 한 칸에 소리와 글자만 있다. 여기서는 **짝 글자**를 보여 준다 —
/// 표에서는 히라가나와 가타카나를 갈라 두지만(한 번에 둘을 외우려 들면 둘 다 흐려진다)
/// 한 글자를 들여다볼 때는 짝을 아는 것이 도움이 된다.
///
/// **한 글자에 머물지 않는다.** 표에서 눌러 들어왔어도 좌우로 밀면 옆 글자가 온다 —
/// 오십음도는 자리가 곧 뜻이라(어느 행 어느 단인지가 소리를 말한다) 이웃한 글자를
/// 이어서 보는 것이 표를 읽는 방식과 같다. 닫고 다시 누르는 왕복이 없어진다.
struct KanaDetail: View {
    /// 처음 보일 글자.
    let start: String
    /// 어느 쪽을 보다 들어왔는가. 그쪽을 크게 둔다.
    var katakana = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.speaker) private var speaker
    /// 지금 보고 있는 글자.
    @State private var currentKana: String?

    init(kana: String, katakana: Bool = false) {
        self.start = kana
        self.katakana = katakana
        _currentKana = State(initialValue: kana)
    }

    private func hiragana(_ kana: String) -> String { kana }
    private func katakanaForm(_ kana: String) -> String { KanaTable.toKatakana(kana) }
    private func hangul(_ kana: String) -> String { KanaToHangul.transliterate(kana) }

    private var position: Int? {
        currentKana.flatMap { kana in KanaTable.ordered.firstIndex(of: kana) }
    }

    var body: some View {
        NavigationStack {
            Pager(items: Glyph.all, current: $currentKana) { glyph in
                ScrollView { page(glyph.kana) }
                .scrollBounceBehavior(.basedOnSize)
            }
            .background(Theme.paper)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 표 어디쯤인지. 넘길 수 있다는 것도 이것이 말해 준다.
                ToolbarItem(placement: .principal) {
                    PagerPosition(index: position, total: Glyph.all.count)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                        .font(Theme.korean(16))
                        .foregroundStyle(Theme.ink)
                }
            }
        }
    }

    /// 한 장.
    private func page(_ kana: String) -> some View {
        VStack(alignment: .leading, spacing: 30) {
            // 큰 글자와 소리. 누르면 읽어 준다.
            Button { speaker.speak(kana, pace: .kana) } label: {
                VStack(alignment: .leading, spacing: 10) {
                    Text(katakana ? katakanaForm(kana) : hiragana(kana))
                        .font(Theme.japanese(84, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    HStack(spacing: 9) {
                        Image(systemName: "speaker.wave.2")
                            .font(.system(size: 15))
                        Text(hangul(kana))
                            .font(Theme.korean(20))
                    }
                    .foregroundStyle(Theme.grey1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(hangul(kana)) 소리 듣기")

            pair(kana)

            Text("소리 글자예요.\n이 글자 하나에는 뜻이 없고, 모여야 낱말이 됩니다.")
                .font(Theme.korean(13))
                .foregroundStyle(Theme.grey2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 28)
        .padding(.top, 8)
        .padding(.bottom, 36)
        .frame(maxWidth: 460, alignment: .leading)
        .frame(maxWidth: .infinity)
    }

    /// 같은 소리를 적는 **짝 글자 하나**.
    ///
    /// 두 벌을 나란히 놓았던 자리다. 그런데 보고 있는 글자는 이미 위에 크게 놓여 있어서,
    /// 여기 한 번 더 두면 같은 글자가 한 화면에 두 번 나온다 — 짝을 보러 내려온 눈이
    /// 둘 중 어느 것이 새것인지 매번 가려내야 했다. **모르는 쪽만 남긴다.**
    private func pair(_ kana: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text("같은 소리")
                    .font(Theme.korean(12))
                    .tracking(0.6)
                    .foregroundStyle(Theme.grey2)
                Theme.rule()
            }
            form(katakana ? "히라가나" : "가타카나",
                 katakana ? hiragana(kana) : katakanaForm(kana))
        }
    }

    private func form(_ label: String, _ glyph: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(Theme.korean(12))
                .foregroundStyle(Theme.grey3)
            Text(glyph)
                .font(Theme.japanese(40))
                .foregroundStyle(Theme.ink)
        }
    }
}

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

    @Environment(\.speaker) private var speaker

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
                                .font(Theme.korean(12))
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
                        .font(Theme.korean(11))
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
                card(item).frame(maxHeight: .infinity)
            }

            HStack(spacing: 12) {
                // 되돌아갈 길. 지나친 글자를 다시 보려고 한 바퀴를 돌 이유가 없다.
                //
                // **검게 채우는 것은 가운데 하나뿐이다.** 이 화면에서 하는 일은 뒤집는
                // 것이고, `이전`·`다음` 은 그 일을 하고 나서 자리를 옮기는 것이다.
                // 셋 중 둘이 번갈아 검어지면 무엇이 지금 할 일인지가 흐려진다.
                button("이전", filled: false) { previous() }
                button(revealed ? "다시 덮기" : "뒤집기", filled: true) {
                    withAnimation(Flip.motion) { revealed.toggle() }
                }
                button("다음", filled: false) { next() }
            }
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

    /// 한 장. **앞뒤가 있는 카드다.**
    ///
    /// `뒤집기` 라고 말해 놓고 아래에 답만 나타나던 자리다. 카드를 그려 두고도 그것이
    /// 돌지 않으면 그 네모는 카드가 아니라 배경이다. 앞면은 글자, 뒷면은 소리 —
    /// 떠올렸다가 확인하는 이 화면의 일이 뒤집는 몸짓과 같은 모양이다.
    private func card(_ item: Card) -> some View {
        FlipCard(angle: revealed ? 180 : 0) {
            face { front(item) }
        } back: {
            face { back(item) }
        }
        .frame(maxWidth: Theme.readWidth)
        .padding(.horizontal, Theme.gutter)
    }

    /// 카드의 면 하나. 연습 카드와 같은 꼴이다.
    private func face<V: View>(@ViewBuilder _ inner: () -> V) -> some View {
        inner()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 54)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Theme.grey3.opacity(0.45), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 10, y: 3)
    }

    /// 앞면 — 글자 하나.
    ///
    /// 화면에 이것 하나뿐이라 본문 크기를 따를 이유가 없다. 표에서 24pt 로 훑던 글자를
    /// 여기서 크게 다시 만나는 것 자체가 "이제 이걸 본다"는 신호다.
    /// 요음은 두 자(きゃ)라 폭이 배가 되므로 줄이지 않고 넘치게 두면 안 된다.
    private func front(_ item: Card) -> some View {
        Text(item.shown)
            .font(Theme.japanese(180, weight: .medium))
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .foregroundStyle(Theme.ink)
            .frame(minHeight: Self.faceHeight)
    }

    /// 뒷면 — 소리.
    ///
    /// **글자를 작게 남긴다.** 뒤집고 나서 "무엇의 답인지"를 다시 찾아 앞면으로
    /// 되돌아가게 하지 않기 위해서다.
    ///
    /// **이 줄이 곧 소리 단추다.** 스피커 모양을 그려 놓고 눌리지 않으면 그것은
    /// 그림이지 단추가 아니다. 아래에 `소리 듣기` 를 따로 두었다가 걷어낸 자리다 —
    /// 같은 일을 하는 것이 화면에 둘일 이유가 없다.
    private func back(_ item: Card) -> some View {
        VStack(spacing: 22) {
            Text(item.shown)
                .font(Theme.japanese(56, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(Theme.grey2)
            Button { speaker.speak(item.kana, pace: .kana) } label: {
                HStack(spacing: 10) {
                    Image(systemName: "speaker.wave.2")
                        .font(.system(size: 20))
                    Text(KanaToHangul.transliterate(item.kana))
                        .font(Theme.korean(34))
                }
                .foregroundStyle(Theme.ink)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("소리 듣기")
        }
        .frame(minHeight: Self.faceHeight)
    }

    /// 두 면이 함께 쓰는 최소 높이. 앞뒤가 크게 다르면 뒤집는 순간 카드가 늘었다 줄었다 한다.
    private static let faceHeight: CGFloat = 210

    /// 순서 다이얼. 범위 다이얼과 같은 문법이다 — 평평하고, 고른 것 하나만 검게 채워진다.
    private var orderDial: some View {
        HStack(spacing: 5) {
            ForEach(Order.allCases) { option in
                let selected = option == order
                Button {
                    order = option
                    reset()
                } label: {
                    // 범위 다이얼과 같은 문법이되 **한 단계 작다.** 같은 일을 하지만
                    // 덜 중요한 결정이라는 것이 크기로 드러난다.
                    Text(option.label)
                        .font(Theme.korean(11.5, weight: selected ? .semibold : .regular))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(selected ? Theme.ink : .clear, in: Capsule())
                        .foregroundStyle(selected ? Theme.paper : Theme.grey2)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var scopeDial: some View {
        HStack(spacing: 7) {
            ForEach(Scope.allCases) { option in
                let selected = option == scope
                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        scope = option
                        reset()
                    }
                } label: {
                    Text(option.label)
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

    private func button(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.korean(17))
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(filled ? Theme.ink : Theme.grey4, in: Capsule())
                .foregroundStyle(filled ? Theme.paper : Theme.grey1)
        }
        .buttonStyle(.plain)
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
