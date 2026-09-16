import SwiftUI
import MworagoCore

/// 묶음 화면의 낱말 한 줄.
///
/// 책장 목록에서는 알약으로 늘어놓아 소리만 훑게 했는데, 여기서는 **뜻까지 세운다** —
/// 한 화 분량을 훑으려고 들어온 화면이라 무엇을 담았는지 읽혀야 한다.
/// 층의 차례는 화면 어디서나 같다 — 가나 · 한글.
struct FolderWordRow: View {
    let word: CollectedWord
    /// 고르는 중인가. 그동안은 줄을 누르면 고르거나 푼다.
    let selecting: Bool
    let isPicked: Bool
    /// 고르는 중이면 고르거나 풀고, 아니면 상세를 편다. 무엇을 할지는 묶음 화면이 정한다.
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Headword(reading: word.reading, kanji: word.kanji, size: .word)
                        if let 품사 = word.partOfSpeech { PartOfSpeechTag(name: 품사) }
                    }
                }
                if !word.gloss.isEmpty {
                    Spacer(minLength: 12)
                    Text(word.gloss)
                        .font(Theme.korean(.sub))
                        .foregroundStyle(Theme.grey2)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(selecting ? "고르거나 풉니다" : "자세히 봅니다")
        .accessibilityAddTraits(selecting && isPicked ? [.isSelected] : [])
    }
}
