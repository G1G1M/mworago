import SwiftUI
import MworagoCore

/// 한 글자만 다르게 들었다면 닿았을 낱말 한 줄. 누르면 입력이 그 소리로 바뀐다.
///
/// **답을 바꿔 치우지 않고 묻는다.** 들은 것은 이 사람이고 사전은 짐작할 뿐이라,
/// 고친 소리를 1위 자리에 몰래 앉히면 바르게 친 사람의 답이 사라진다. 그래서 곁에 한 줄로
/// 세우고, 고를지는 누르는 손이 정한다.
///
/// 줄의 무게는 「다른 뜻」 단추와 같다 — 회색 글에 꼬리표·테두리 없이. 카드에서 눌러야 할
/// 것은 갈피표와 소리이고, 이것은 「이런 길도 있다」는 안내라 그 둘과 겨루면 안 된다.
struct SoundAlikeRow: View {
    let alike: SoundAlike
    /// 앞에 붙는 말. 카드에서는 「갓코로 들렸다면」, 입력 위에서는 「혹시 아리가토?」.
    let lead: String
    let onPick: () -> Void

    @Environment(TranslationDesk.self) private var desk

    private var gloss: String {
        let entry = alike.result.entry
        guard entry.koreanGloss == nil else { return entry.displayGloss }
        return desk.english[entry.displayGloss] ?? entry.displayGloss
    }

    var body: some View {
        Button(action: onPick) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(lead)
                    .font(Theme.korean(.sub))
                    .foregroundStyle(Theme.grey2)
                Text(alike.result.kanji ?? alike.result.reading)
                    .font(Theme.japanese(.sub, weight: .medium))
                    .foregroundStyle(Theme.grey1)
                Text(gloss)
                    .font(Theme.korean(.sub))
                    .foregroundStyle(Theme.grey2)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(Theme.icon(.caret, weight: .medium))
                    .foregroundStyle(Theme.grey3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(lead) \(alike.result.reading) \(gloss)")
        .accessibilityHint("입력을 \(alike.hangul)로 바꿔요")
        // 영어로 남은 뜻이면 옮겨 달라고 보낸다. 카드와 같은 길이다.
        .task(id: alike.hangul) {
            if alike.result.entry.koreanGloss == nil { desk.english.ask([alike.result.entry.displayGloss]) }
        }
    }
}

extension SoundAlike {
    /// 카드에 붙는 머리말 — 무엇을 다르게 들었다고 보는지 소리로 말한다.
    var heardAs: String { "\(hangul)\(Self.ro(after: hangul)) 들렸다면" }

    /// 받침이 있으면 「으로」, 없거나 ㄹ 이면 「로」.
    static func ro(after word: String) -> String {
        guard let last = word.last, let syllable = HangulSyllable(last),
              let final = syllable.final, final != "ㄹ" else { return "로" }
        return "으로"
    }
}
