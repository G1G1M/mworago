import SwiftUI
import MworagoCore

/// 한 장. **앞뒤가 있는 카드다.**
///
/// 앞면은 문제 — 가나와, 그것을 읽는 데 쓰는 것들(품사·소리). 뒷면은 답 —
/// 한글 음차와 뜻. 뒷면에도 가나를 작게 남긴다. 뒤집고 나서 "무엇의 답인지"를
/// 다시 찾아 앞면으로 되돌아가게 하지 않기 위해서다.
///
/// **덩어리는 가운데, 글줄은 왼쪽.** 줄마다 시작점이 다르면 눈이 매번 첫 글자를
/// 찾아야 한다. 한 자리에서 시작하되 그 덩어리를 폭에 맞춰 재서 화면 가운데 세운다.
struct PracticeCard: View {
    let word: CollectedWord
    /// 뒤집혔는가. 넘기면 도로 덮이는 일은 연습 화면이 한다.
    let revealed: Bool

    var body: some View {
        FlipCard(angle: revealed ? 180 : 0) {
            face { question }
        } back: {
            face { answer }
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
            .cardSurface()
    }

    /// 앞면 — 문제.
    ///
    /// **가나부터 보인다.** 한글 음차는 찾을 때 쓰는 열쇠이지 익힐 것이 아니다.
    /// 그것을 앞에 두면 한글 음차를 보고 뜻을 떠올리는 연습이 되는데, 자막에 뜨는 것은
    /// `いたい` 이지 `이타이` 가 아니다.
    ///
    /// **품사와 소리는 앞면에 둔다.** 답이 아니라 문제의 일부다 — 동사인지 명사인지를
    /// 알고 뜻을 떠올리는 것이 실제로 하는 일이고, 뒤집기 전에 들어 보는 것이 곧 문제다.
    private var question: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(word.reading)
                .font(Theme.japanese(.display, weight: .medium))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            marks
        }
        .frame(minHeight: Self.faceHeight, alignment: .leading)
    }

    /// 뒷면 — 답.
    ///
    /// 층의 차례는 화면 어디서나 같다 — 가나 · 한글 · 뜻. 한글 음차를 남기는 것은
    /// **"내가 이것을 어떻게 찾았는지"의 기록**이라서다. 소리와 글자를 잇는 다리인데,
    /// 답의 일부지 문제는 아니다.
    private var answer: some View {
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

    /// 낱말 옆에 붙는 것들 — 품사와 소리.
    ///
    /// **품사는 앞면에 둔다.** 답이 아니라 문제의 일부다 — 동사인지 명사인지를 알고
    /// 뜻을 떠올리는 것이 실제로 하는 일이다. 소리도 마찬가지로, 뒤집기 전에
    /// 들어 보는 것이 곧 문제다.
    @ViewBuilder
    private var marks: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            if let 품사 = word.partOfSpeech { PartOfSpeechTag(name: 품사) }
            SpeakButton(text: word.reading, size: 18)
        }
    }
}
