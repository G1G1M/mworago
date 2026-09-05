import SwiftUI
import MworagoCore

/// 되살린 문장의 뜻 한 줄.
///
/// 낱말 카드는 조각마다 뜻을 주지만, 조각을 이어 붙인다고 문장이 되지는 않는다 —
/// 조사와 활용이 한국어 어순으로 다시 서야 한다. 그 일을 여기서 한다.
///
/// **애플 번역기를 쓴다.** 처음에는 온디바이스 모델(`FoundationModels`)로 갔다가 물렸다.
/// 그쪽은 무엇이든 만들어 내는 물건이라 안전 필터가 옮기는 일까지 막는데, 자막 문장 60개 중
/// **58%가 막혔다** — `彼は猫が好きではない`(고양이를 좋아하지 않는다)처럼 위험한 말이
/// 한 글자도 없는 문장이 걸렸다. 번역기는 같은 60개를 **전부** 옮겼다.
///
/// 덤으로 기기가 넓어졌다. 번역기는 iOS 18 부터라 Apple Intelligence 를 지원하지 않는
/// 기본 아이패드에서도 돌아간다 — 이 앱이 지켜 온 자리다.
struct SentenceMeaning: View {
    let segments: [Segment]

    @Environment(TranslationDesk.self) private var desk

    /// 문장을 이루는 조각들. 통째로 찾은 것은 문장의 한 부분이 아니다.
    private var parts: [Segment] { segments.filter { !$0.isWhole } }

    /// 번역기에 넘길 원문. 화면에 보이는 그 문장을 그대로 준다.
    /// 무엇을 넘길지는 `Segment.forTranslation` 이 정한다 — 그 자리에 이유를 적어 두었다.
    private var source: String { parts.forTranslation() }

    /// 조각이 하나뿐이면 묻지 않는다. 그때는 카드에 뜬 뜻이 이미 답이다.
    private var hasSentence: Bool { parts.count >= 2 }

    private var korean: String? { hasSentence ? desk.japanese[source] : nil }

    /// 뜻이 안 뜨는 까닭. 언어팩이 있는 기기에서는 늘 `nil` 이라 아무것도 안 그린다.
    ///
    /// **뜻이 뜰 자리가 있을 때만 말한다** — 조각 하나짜리 검색에는 애초에 문장 뜻이
    /// 없으므로, 거기서 언어팩 이야기를 꺼내면 없는 문제를 알리는 셈이다.
    private var notice: String? {
        guard hasSentence, korean == nil else { return nil }
        return desk.japanesePack.notice
    }

    var body: some View {
        // 비어 있어도 자리는 남긴다. 아무것도 그리지 않는 뷰는 화면에서 통째로 사라져서
        // 여기 붙인 `task` 도 함께 사라진다 — 그러면 물어보러 가지도 못한다.
        VStack(alignment: .leading, spacing: 6) {
            if let korean {
                // **이름표를 달지 않는다.** 문장 아래 한 줄이 그 문장의 뜻이라는 것은
                // 자리가 이미 말해 준다. "뜻"이라고 적어 두면 읽을 것이 하나 늘 뿐이다.
                Text(korean)
                    // **발음 줄과 같은 크기다.** 카드에서 발음과 뜻이 둘 다 14 이고
                    // 색으로만 갈리는 것과 같다. 17 이었을 때는 발음(16)보다 1 만 커서
                    // 위계가 아니라 어긋난 값으로 보였다.
                    .font(Theme.korean(16))
                    // **가르는 것은 색뿐이다.** 위 두 줄은 사용자가 친 소리를 적은 것이고
                    // 이 줄은 기계가 옮긴 말이다. 카드도 발음 grey3 · 뜻 grey1 로 가른다.
                    .foregroundStyle(Theme.grey1)
                    .fixedSize(horizontal: false, vertical: true)
                    // 위 두 줄과 갈라 놓는 자리.
                    //
                    // **가나와 발음은 한 덩어리다** — 같은 소리를 두 글자로 적은 것이라
                    // 8 로 붙여 둔다. 뜻은 다른 층이므로 더 벌린다. 카드가 5 와 12 로
                    // 벌린 그 비율(2.4배)을 이 크기에 옮기면 8 과 19 가 된다.
                    // 바깥 세로 간격 8 위에 11 을 더해 그 19 를 만든다.
                    .padding(.top, 11)
            } else if let notice {
                // **뜻이 아니라 안내다.** 뜻 줄보다 작고 흐리게 두어, 이 자리에 들어올
                // 진짜 뜻과 헷갈리지 않게 한다. 뜻이 뜨기 시작하면 이 줄은 사라진다.
                Text(notice)
                    .font(Theme.korean(13))
                    .foregroundStyle(Theme.grey2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 11)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // **치는 동안에는 묻지 않는다.** 검색은 글자마다 즉시 갱신되지만 번역은 그보다
        // 느리므로 손이 멎은 뒤에 보낸다. 이미 옮긴 문장이면 기다리지 않고 곧바로 뜬다.
        .task(id: source) {
            guard hasSentence, desk.japanese[source] == nil else { return }
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            desk.japanese.ask([source])
        }
    }
}
