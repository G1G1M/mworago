import SwiftUI
import MworagoCore

/// 앱을 열지 않고 찾았을 때 뜨는 작은 창.
///
/// **찾기 화면의 문장 머리줄과 같은 꼴이다** — 꼬리표 · 가나 · 친 한글 · 뜻, 같은 글꼴과
/// 같은 색과 같은 여백. 앱에서 보던 얼굴이 그대로 떠야 이 창이 그 앱의 것인 줄 안다.
/// 다른 것은 하나다: 조각을 눌러 고르는 일이 없으므로 가나를 한 줄로 이어 적는다.
/// 낱말을 하나씩 뜯어보는 것은 앱을 열어서 할 일이다.
struct QuickAnswerView: View {
    let result: QuickLookup.Result

    private var answer: QuickAnswer { result.answer }

    /// 찾기 화면과 같은 꼬리표 — 문장이면 `문장`, 낱말이면 품사.
    private var tag: String? {
        answer.isSentence ? CollectedWord.sentenceTag : answer.wordClass?.displayName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if answer.isEmpty {
                empty
            } else {
                // 찾기 화면의 문장 머리줄처럼 꼬리표 곁에 소리 단추가 선다. 이 창의 단추는
                // 화면이 아니라 시스템이 앱을 깨워 부르므로 앱의 `SpeakButton` 대신 동작을 건다.
                HStack(spacing: 9) {
                    if let tag { PartOfSpeechTag(name: tag) }
                    Button(intent: SpeakSentenceIntent(text: answer.kana)) {
                        Image(systemName: "speaker.wave.2")
                            .font(Theme.icon(.action))
                            .foregroundStyle(.secondary)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("소리 듣기")
                }
                Text(answer.kana)
                    .font(Theme.japanese(.piece, weight: .medium))
                    .foregroundStyle(.primary)
                    // 긴 문장은 두 줄 안에서 글자를 줄인다. 창 높이가 340pt 를 넘으면
                    // 시스템이 창을 스크롤로 바꿔 뜻이 아래로 밀린다.
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                Text(answer.typed)
                    .font(Theme.korean(.body))
                    .foregroundStyle(.secondary)
                meaning
                    .padding(.top, 11)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 24)
        .padding(.bottom, 32)
        // **글자 색은 앱의 회색 사다리 대신 시스템의 위계(`primary`·`secondary`)를 쓴다.**
        // 유리 판은 뒤에 비치는 것에 따라 밝기가 바뀌는데, 앱의 회색은 종이 위에서 고른 값이라
        // 밝은 잠금 화면 사진 위에서 친 한글과 뜻이 거의 안 읽혔다(실기기 캡처, 2026-10-04).
        // 시스템 위계는 판의 비침에 맞춰 대비를 잡아 준다. 뜻은 이 창의 주인공이라 `primary` 다.
        // **바닥을 칠하지 않는다.** 이 창은 시스템의 유리 판 위에 놓이고, 그 아래 「완료」 단추도
        // 같은 유리다. 종이색을 깔면 창 안쪽만 종이가 되어 판과 단추가 두 재질로 갈린다.
        // 앱의 입력 바도 유리이므로, 판을 비워 두는 편이 앱과 같은 얼굴이 된다.
    }

    @ViewBuilder
    private var meaning: some View {
        if let meaning = result.meaning {
            Text(meaning)
                .font(Theme.korean(.body))
                .foregroundStyle(.primary)
                .lineLimit(3)
        } else {
            Text(notice)
                .font(Theme.korean(.sub))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 뜻이 비었을 때의 한 줄. 앱의 안내와 같은 말이되, 이 창에는 낱말 뜻이 따로 없으므로
    /// "낱말 뜻은 그대로 나와요"는 뺀다.
    private var notice: String {
        result.pack.notice(mentioningWords: false) ?? "뜻을 옮기지 못했어요. 앱에서 다시 찾아봐 주세요."
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(SearchNotice.notFoundTitle)
                .font(Theme.korean(.heading, weight: .semibold))
                .foregroundStyle(.primary)
            Text(SearchNotice.notFoundDetail)
                .font(Theme.korean(.body))
                .foregroundStyle(.secondary)
        }
    }
}
