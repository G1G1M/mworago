import SwiftUI
import MworagoCore

/// 책장 `모두` 목록의 낱말 하나.
///
/// **담을 때 보였던 뜻을 그대로 붙든다** — 뜻이 나중에 좋아지더라도
/// 무엇을 보고 담았는지가 그 사람의 기억과 맞다.
struct LibraryWordRow: View {
    let word: CollectedWord
    /// 고르는 중인가. 그동안은 줄을 누르면 고르고, 갈피표는 감춘다.
    let selecting: Bool
    let isPicked: Bool
    /// 고르는 중이면 고르거나 풀고, 아니면 상세를 편다. 무엇을 할지는 책장이 정한다.
    let onTap: () -> Void
    /// 갈피표를 눌러 책장에서 뺀다.
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Headword(reading: word.reading, kanji: word.kanji, size: .word)
                        if let 품사 = word.partOfSpeech { PartOfSpeechTag(name: 품사) }
                    }
                    Text(word.hangul)
                        .font(Theme.korean(.sub))
                        .foregroundStyle(Theme.grey3)
                    if !word.gloss.isEmpty {
                        Text(word.gloss)
                            .font(Theme.korean(.sub))
                            .foregroundStyle(Theme.grey1)
                            .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(selecting ? "고르거나 풉니다" : "자세히 봅니다")
            .accessibilityAddTraits(selecting && isPicked ? [.isSelected] : [])

            // 고르는 중에는 갈피표를 감춘다. 한 줄에 고르는 손과 빼는 손이 같이 있으면
            // 고르려다 빼는 일이 생기고, 그것은 되돌릴 수 없다.
            if !selecting {
                Button(action: onRemove) {
                    Image(systemName: "bookmark.fill")
                        // 찾기의 갈피표와 같은 15 다. 같은 기호가 같은 일(담기·빼기)을 한다.
                        .font(Theme.icon(.control))
                        .foregroundStyle(Theme.ink)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(word.reading) 빼기")
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.vertical, 16)
    }
}
