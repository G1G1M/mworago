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
    /// 받아쓰기라면 그 판. 있으면 앞면이 가나 대신 소리가 된다.
    var dictation: DictationFace? = nil

    @Environment(\.speaker) private var speaker

    /// 받아쓰기 한 장의 형편 — 무엇을 쳤고, 그것이 이 낱말에 닿는지.
    struct DictationFace: Equatable {
        var typed: String
        var verdict: Dictation.Verdict?
    }

    var body: some View {
        FlipCard(angle: revealed ? 180 : 0) {
            face { if dictation != nil { listening } else { question } }
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
            if let dictation, let verdict = dictation.verdict {
                DictationVerdictLine(typed: dictation.typed, verdict: verdict)
                    .padding(.bottom, 6)
            }
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

    /// 받아쓰기의 앞면 — **가나를 가린다.** 글자를 보이면 받아쓰기가 아니라 옮겨 적기다.
    /// 소리 단추를 크게 두고, 장이 넘어오면 화면이 먼저 한 번 들려준다(`PracticeView`).
    private var listening: some View {
        VStack(alignment: .leading, spacing: 18) {
            // **두 단추를 한 벌로 세운다.** 큰 스피커 그림 옆에 작은 거북이와 글자를 붙였더니
            // 크기도 꼴도 달라 하나는 그림, 하나는 글줄처럼 보였다. 같은 크기의 동그라미 둘로
            // 세워, 같은 일(소리 듣기)의 두 빠르기라는 것이 꼴로 읽히게 한다.
            // 이름(「듣기」·「느리게」)은 달지 않는다 — 그림이 이미 말하고, 글이 붙으면 카드의
            // 안내문과 겹쳐 시끄러웠다. 읽어 주기에는 이름을 준다.
            HStack(spacing: 14) {
                listenButton("speaker.wave.2.fill", tint: Theme.ink, pace: .of(word.reading))
                    .accessibilityLabel("다시 듣기")
                listenButton("tortoise.fill", tint: Theme.grey1, pace: .kana)
                    .accessibilityLabel("느리게 듣기")
            }
            Text("들린 대로 한글로 쳐 보세요")
                .font(Theme.korean(.body))
                .foregroundStyle(Theme.grey2)
            if let 품사 = word.partOfSpeech { PartOfSpeechTag(name: 품사) }
        }
        .frame(minHeight: Self.faceHeight, alignment: .leading)
    }

    /// 받아쓰기의 소리 단추 하나 — 동그라미 안에 그림.
    ///
    /// **느리게는 받아쓰기에서만 선다.** 낱말은 자막에서 만나는 빠르기로 읽는데
    /// (`SpeechPace.word`), 그 빠르기로 두세 번 들어도 안 잡히는 소리는 늦춰 들어야 어느
    /// 글자가 어긋났는지 보인다 — 촉음·장음이 그렇다. 글자 익히기가 쓰는 가장 느린
    /// 빠르기(`kana`)를 빌린다.
    private func listenButton(_ icon: String, tint: Color, pace: SpeechPace) -> some View {
        Button {
            speaker.speak(word.reading, pace: pace)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 56, height: 56)
                .background(Theme.grey4, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
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

/// 받아쓰기의 답 한 줄 — 친 소리가 이 낱말에 닿는지.
///
/// **맞았다 · 틀렸다로 말하지 않는다.** 한글로 적는 정답은 하나가 아니고, 묻는 것은
/// 「이렇게 쳐도 찾아지는가」다. 닿지 않았을 때도 어느 글자를 다르게 들었는지를 말해 준다 —
/// 그 한 글자가 다음에 같은 소리를 들을 때 고칠 자리다.
struct DictationVerdictLine: View {
    let typed: String
    let verdict: Dictation.Verdict

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(Theme.korean(.body, weight: .semibold))
                .foregroundStyle(Theme.ink)
            if let detail {
                Text(detail)
                    .font(Theme.korean(.sub))
                    .foregroundStyle(Theme.grey2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        switch verdict {
        case .reached: "\(typed) — 이렇게 쳐도 찾아져요"
        case .close: "\(typed) — 한 글자만 달랐어요"
        case .missed: "\(typed) — 다르게 들렸어요"
        case .empty: "아직 안 쳤어요"
        }
    }

    private var detail: String? {
        switch verdict {
        case .close(let hangul, let change):
            "\(hangul)\(SoundAlike.ro(after: hangul)) 치면 닿아요. \(Self.reason(change))"
        case .missed: "아래 한글 소리와 견줘 보세요."
        case .reached, .empty: nil
        }
    }

    static func reason(_ change: SoundAlike.Change) -> String {
        switch change {
        case .voicing: "탁음(ㄱ·ㄷ·ㅂ·ㅈ)을 거센소리로 들었어요."
        case .liquid: "ら행은 ㄹ과 ㄷ 사이로 들려요."
        case .finalDropped: "없는 받침을 들었어요."
        case .nasalAdded: "ん(ㄴ 받침)을 흘려들었어요."
        }
    }
}
