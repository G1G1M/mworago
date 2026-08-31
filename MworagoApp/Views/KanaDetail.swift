import SwiftUI
import MworagoCore

/// 글자 하나.
///
/// 표는 훑는 곳이라 한 칸에 소리와 글자만 있다. 여기서는 **히라가나와 가타카나를
/// 나란히** 놓는다 — 표에서는 일부러 갈라 두었지만(한 번에 둘을 외우려 들면 둘 다
/// 흐려진다) 한 글자를 들여다볼 때는 짝을 아는 것이 도움이 된다.
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
                    Button { KanaVoice.speak(kana) } label: {
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

    /// 히라가나와 가타카나. 같은 소리를 적는 두 글자라 나란히 둔다.
    private var pair: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text("같은 소리")
                    .font(Theme.korean(12))
                    .tracking(0.6)
                    .foregroundStyle(Theme.grey2)
                Rectangle().fill(Theme.grey3).frame(height: 0.5)
            }
            HStack(spacing: 34) {
                form("히라가나", hiragana)
                form("가타카나", katakanaForm)
            }
        }
    }

    private func form(_ label: String, _ glyph: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(Theme.korean(12))
                .foregroundStyle(Theme.grey3)
            Text(glyph)
                .font(Theme.japanese(34))
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

    @State private var scope: Scope = .hiragana
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            scopeDial
                .padding(.horizontal, 28)
                .padding(.top, 6)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 22) {
                Text(shown)
                    .font(Theme.japanese(96, weight: .medium))
                    .foregroundStyle(Theme.ink)

                // 뒤집기 전에는 자리만 잡아 둔다. 답이 나타날 때 글자가 밀려 올라가면
                // 눈이 따라가느라 정작 답을 놓친다.
                HStack(spacing: 9) {
                    Image(systemName: "speaker.wave.2")
                        .font(.system(size: 15))
                    Text(KanaToHangul.transliterate(current))
                        .font(Theme.korean(24))
                }
                .foregroundStyle(Theme.grey1)
                .opacity(revealed ? 1 : 0)
                .accessibilityHidden(!revealed)
            }
            .frame(maxWidth: 460, alignment: .leading)
            .padding(.horizontal, 28)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                button(revealed ? "소리 듣기" : "뒤집기", filled: true) {
                    if revealed {
                        KanaVoice.speak(current)
                    } else {
                        withAnimation(.snappy(duration: 0.18)) { revealed = true }
                    }
                }
                button("다음", filled: false) { next() }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 34)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scopeDial: some View {
        HStack(spacing: 6) {
            ForEach(Scope.allCases) { option in
                let selected = option == scope
                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        scope = option
                        next()
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
                .font(Theme.korean(16))
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(filled ? Theme.ink : Theme.grey4, in: Capsule())
                .foregroundStyle(filled ? Theme.paper : Theme.grey1)
        }
        .buttonStyle(.plain)
    }

    /// 다음 글자. 같은 글자가 잇달아 나오면 넘긴 것 같지 않다.
    private func next() {
        var pick = current
        var guard_ = 0
        while pick == current, guard_ < 8 {
            pick = Self.pool.randomElement() ?? "あ"
            guard_ += 1
        }
        withAnimation(.snappy(duration: 0.18)) {
            current = pick
            asKatakana = scope == .katakana || (scope == .both && Bool.random())
            revealed = false
        }
    }
}
