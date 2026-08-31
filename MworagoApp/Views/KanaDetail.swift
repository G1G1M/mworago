import SwiftUI
import MworagoCore

/// 글자 하나.
///
/// 표는 훑는 곳이라 한 칸에 소리와 글자만 있다. 여기서는 **짝 글자**를 보여 준다 —
/// 표에서는 히라가나와 가타카나를 갈라 두지만(한 번에 둘을 외우려 들면 둘 다 흐려진다)
/// 한 글자를 들여다볼 때는 짝을 아는 것이 도움이 된다.
struct KanaDetail: View {
    let kana: String
    /// 어느 쪽을 보다 들어왔는가. 그쪽을 크게 둔다.
    var katakana = false

    @Environment(\.dismiss) private var dismiss

    private var hiragana: String { kana }
    private var katakanaForm: String { KanaTable.toKatakana(kana) }
    private var hangul: String { KanaToHangul.transliterate(kana) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    // 큰 글자와 소리. 누르면 읽어 준다.
                    Button { Voice.speak(kana) } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(katakana ? katakanaForm : hiragana)
                                .font(Theme.japanese(84, weight: .medium))
                                .foregroundStyle(Theme.ink)
                            HStack(spacing: 9) {
                                Image(systemName: "speaker.wave.2")
                                    .font(.system(size: 15))
                                Text(hangul)
                                    .font(Theme.korean(20))
                            }
                            .foregroundStyle(Theme.grey1)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(hangul) 소리 듣기")

                    pair

                    Text("소리 글자예요. 이 글자 하나에는 뜻이 없고, 모여야 낱말이 됩니다.")
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
            .background(Theme.paper)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                        .font(Theme.korean(16))
                        .foregroundStyle(Theme.ink)
                }
            }
        }
    }

    /// 같은 소리를 적는 **짝 글자 하나**.
    ///
    /// 두 벌을 나란히 놓았던 자리다. 그런데 보고 있는 글자는 이미 위에 크게 놓여 있어서,
    /// 여기 한 번 더 두면 같은 글자가 한 화면에 두 번 나온다 — 짝을 보러 내려온 눈이
    /// 둘 중 어느 것이 새것인지 매번 가려내야 했다. **모르는 쪽만 남긴다.**
    private var pair: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text("같은 소리")
                    .font(Theme.korean(12))
                    .tracking(0.6)
                    .foregroundStyle(Theme.grey2)
                Rectangle().fill(Theme.grey3).frame(height: 0.5)
            }
            form(katakana ? "히라가나" : "가타카나",
                 katakana ? hiragana : katakanaForm)
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

    @State private var scope: Scope = .hiragana
    @State private var order: Order = .random
    /// 이번 판에 물을 차례. 범위와 순서가 바뀌면 다시 짠다 —
    /// **범위 셋이 각자 제 차례를 갖는다.**
    @State private var deck: [String] = KanaQuiz.pool.shuffled()
    @State private var at = 0
    @State private var current: String = KanaQuiz.pool.randomElement() ?? "あ"
    @State private var asKatakana = false
    @State private var revealed = ProcessInfo.processInfo.arguments.contains("--revealed")

    /// 표에 실린 글자 전부. 빈 자리(ゐ·ゑ)는 뺀다 — 표에서는 자리를 지켜야 행과 단이
    /// 맞지만, 여기서는 안 쓰는 소리를 물을 이유가 없다.
    private static let pool: [String] = KanaTable.charts
        .flatMap(\.rows)
        .flatMap { $0 }
        .compactMap { $0 }

    private var shown: String {
        asKatakana ? KanaTable.toKatakana(current) : current
    }

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
                HStack(spacing: 12) {
                    orderDial
                    // 종류가 다른 것 사이에는 선을 세운다. 자리로 갈리면 글자로
                    // 설명하지 않아도 된다.
                    Divider()
                        .overlay(Theme.grey3)
                        .frame(height: 14)
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

            Spacer(minLength: 0)

            VStack(spacing: 26) {
                // 화면에 이것 하나뿐이라 본문 크기를 따를 이유가 없다. 표에서 24pt 로
                // 훑던 글자를 여기서 크게 다시 만나는 것 자체가 "이제 이걸 본다"는 신호다.
                // 요음은 두 자(きゃ)라 폭이 배가 되므로 줄이지 않고 넘치게 두면 안 된다.
                Text(shown)
                    .font(Theme.japanese(180, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(Theme.ink)

                // 뒤집기 전에는 자리만 잡아 둔다. 답이 나타날 때 글자가 밀려 올라가면
                // 눈이 따라가느라 정작 답을 놓친다.
                HStack(spacing: 10) {
                    Image(systemName: "speaker.wave.2")
                        .font(.system(size: 18))
                    Text(KanaToHangul.transliterate(current))
                        .font(Theme.korean(28))
                }
                .foregroundStyle(Theme.grey1)
                .opacity(revealed ? 1 : 0)
                .accessibilityHidden(!revealed)
            }
            .frame(maxWidth: Theme.readWidth)
            .padding(.horizontal, Theme.gutter)

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                button(revealed ? "소리 듣기" : "뒤집기", filled: true) {
                    if revealed {
                        Voice.speak(current)
                    } else {
                        withAnimation(.snappy(duration: 0.18)) { revealed = true }
                    }
                }
                button("다음", filled: false) { next() }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, Theme.screenBottom)
        }
        .frame(maxWidth: .infinity)
    }

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
        at = (at + 1) % deck.count
        withAnimation(.snappy(duration: 0.18)) {
            current = deck[at]
            asKatakana = scope == .katakana || (scope == .both && Bool.random())
            revealed = false
        }
    }

    /// 처음으로. **랜덤이면 다시 섞는다** — 초기화가 같은 차례를 되풀이하면
    /// 무작위라고 할 수 없다.
    private func reset() {
        deck = order == .random ? Self.pool.shuffled() : Self.pool
        at = 0
        withAnimation(.snappy(duration: 0.18)) {
            current = deck.first ?? "あ"
            asKatakana = scope == .katakana || (scope == .both && Bool.random())
            revealed = false
        }
    }
}
