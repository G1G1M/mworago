import SwiftUI
// 번역 프레임워크는 아직 Swift 6 의 격리 표시를 달고 있지 않다. 그대로 두면
// 화면 쪽에서 연 세션을 번역이 도는 자리로 넘길 수 없다고 컴파일러가 막는다.
@preconcurrency import Translation
import MworagoCore

/// 되살린 문장의 뜻 한 줄.
///
/// 낱말 카드는 조각마다 뜻을 주지만, 조각을 이어 붙인다고 문장이 되지는 않는다 —
/// 조사와 활용이 한국어 어순으로 다시 서야 한다. 그 일을 여기서 한다.
///
/// **애플 번역기를 쓴다.** 처음에는 온디바이스 모델(`FoundationModels`)로 갔다가 물렸다.
/// 그쪽은 무엇이든 만들어 내는 물건이라 안전 필터가 옮기는 일까지 막는데, 자막 문장 60개 중
/// **58%가 막혔다** — `彼は猫が好きではない`(고양이를 좋아하지 않는다)처럼 위험한 말이
/// 한 글자도 없는 문장이 걸렸다. 완화 옵션(`permissiveContentTransformations`)을 켜고 재도
/// 52%였고, 다시 물어도 막히는 문장은 계속 막혔다. 번역기는 같은 60개를 **전부** 옮겼다.
///
/// 덤으로 기기가 넓어졌다. 번역기는 iOS 18 부터라 Apple Intelligence 를 지원하지 않는
/// 기본 아이패드에서도 돌아간다. 이 앱이 지켜 온 자리다 — 폴백이 곧 시장이다.
struct SentenceMeaning: View {
    let segments: [Segment]

    @State private var configuration: TranslationSession.Configuration?
    @State private var korean: String?

    /// 문장을 이루는 조각들. 통째로 찾은 것은 문장의 한 부분이 아니다.
    private var parts: [Segment] { segments.filter { !$0.isWhole } }

    /// 번역기에 넘길 원문.
    ///
    /// **가나로 넘긴다.** 화면에는 한자로 보이지만(`彼は怒っている`) 번역기에는 소리만 준다.
    /// 한자를 박는 것은 "이 낱말은 酒 가 아니라 避け 다"라고 못 박는 일이라, 우리가 1위를
    /// 잘못 고른 자리에서 번역기가 스스로 바로잡을 여지를 뺏는다 —
    /// `さけに溺れている`("술에 취해 있다")가 `避けに溺れている`("피하기 위해 빠져들고 있다")가
    /// 됐다. 60개를 두 벌로 재어 보니 한자를 박아 좋아진 문장 8개와 나빠진 문장 8개가
    /// 상쇄됐고, 나빠질 때가 더 크게 틀렸다. **번역기는 일본어 문맥을 우리보다 잘 본다.**
    private var source: String { parts.kana }

    /// 조각이 하나뿐이면 묻지 않는다. 그때는 카드에 뜬 뜻이 이미 답이다.
    private var hasSentence: Bool { parts.count >= 2 }

    var body: some View {
        // 넘길 원문을 여기서 붙들어 둔다. 아래 클로저는 이 뷰 바깥에서 도는 자리라
        // 뷰의 것을 그대로 읽으면 경계를 넘는다.
        let source = self.source
        // **비어 있어도 자리는 남긴다.** 아무것도 그리지 않는 뷰는 화면에서 통째로 사라져서
        // 여기 붙인 `task` 도 함께 사라진다 — 그러면 물어보러 가지도 못한다.
        return VStack(alignment: .leading, spacing: 6) {
            if let korean, !korean.isEmpty {
                Text("뜻")
                    .font(Theme.korean(12))
                    .foregroundStyle(Theme.grey3)
                Text(korean)
                    .font(Theme.korean(17))
                    // **사전 뜻보다 옅다.** 카드의 뜻은 사전에 실린 것이지만 이 한 줄은
                    // 기계가 옮긴 것이라, 같은 무게로 보이면 안 된다.
                    .foregroundStyle(Theme.grey1)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.gutter)
        .task(id: source) { await ask() }
        .translationTask(configuration) { session in
            // 못 옮기면 **자리 자체가 없다.** 언어팩이 없든 기기가 지원하지 않든
            // 화면에 사정을 늘어놓지 않는다 — 뜻을 찾으러 온 사람에게 할 말이 아니다.
            korean = try? await session.translate(source).targetText
        }
    }

    /// 문장이 바뀌면 다시 묻는다.
    ///
    /// 검색은 글자를 칠 때마다 즉시 갱신되지만 번역은 0.3초쯤 걸린다. 치는 동안 계속 물으면
    /// 버려질 답을 만드느라 배터리를 쓰므로, **손이 멎은 뒤에** 한 번 묻는다.
    private func ask() async {
        korean = nil
        guard hasSentence else { return }
        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }

        // **못 옮기는 자리에서는 세션을 열지도 않는다.**
        //
        // 열어 놓고 실패를 삼키는 것으로는 모자랐다. 시뮬레이터에서 돌려 보니 애플이
        // "Translation is not supported on simulated devices" 라는 시트를 대신 띄웠다 —
        // 우리가 조용히 있으려 해도 시스템이 말을 한다. 번역을 지원하지 않는 기기에서도
        // 같은 일이 날 수 있으니, 물어볼 수 있는 자리인지 먼저 보고 연다.
        let status = await LanguageAvailability().status(from: Locale.Language(identifier: "ja"),
                                                        to: Locale.Language(identifier: "ko"))
        guard status != .unsupported else { return }

        if configuration == nil {
            configuration = TranslationSession.Configuration(
                source: Locale.Language(identifier: "ja"),
                target: Locale.Language(identifier: "ko"))
        } else {
            // 같은 설정으로는 세션이 다시 돌지 않는다. 문장이 바뀌었음을 이렇게 알린다.
            configuration?.invalidate()
        }
    }
}
