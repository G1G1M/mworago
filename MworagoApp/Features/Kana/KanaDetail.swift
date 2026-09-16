import SwiftUI
import MworagoCore

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
                        .font(Theme.korean(.body))
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
                        .font(Theme.japanese(.glyph, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    HStack(spacing: 9) {
                        Image(systemName: "speaker.wave.2")
                            .font(.system(size: 15))
                        Text(hangul(kana))
                            .font(Theme.korean(.title))
                    }
                    .foregroundStyle(Theme.grey1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(hangul(kana)) 소리 듣기")

            pair(kana)

            Text("소리 글자예요.\n이 글자 하나에는 뜻이 없고, 모여야 낱말이 됩니다.")
                .font(Theme.korean(.sub))
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
                    .font(Theme.korean(.tag))
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
                .font(Theme.korean(.tag))
                .foregroundStyle(Theme.grey3)
            Text(glyph)
                .font(Theme.japanese(.display))
                .foregroundStyle(Theme.ink)
        }
    }
}
