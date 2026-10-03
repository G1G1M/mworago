import Foundation
import MworagoDomain

/// 앱을 열지 않고 내놓는 짧은 답 — 동작 버튼 · Siri · 단축어가 띄우는 작은 창 하나.
///
/// 그 창에서 원하는 것은 **뜻 한 줄**이다. 찾기 화면처럼 낱말을 하나씩 뜯어 보이면
/// 창이 길어지고 정작 뜻이 아래로 밀린다. 뜯어보는 것은 앱을 열어서 할 일이다.
///
/// 뜻은 두 길로 온다. 사전이 이미 아는 것이면(`knownMeaning`) 그대로 쓰고, 아니면
/// 원문(`forTranslation`)을 기기의 번역기에 넘긴다. 사전의 뜻은 사람이 다듬은 값이라
/// 번역기가 문맥 없이 옮긴 것보다 낫다 — `콘니치와` 를 번역기에 주면 "오늘은"이 온다.
public struct QuickAnswer: Sendable, Equatable {

    /// 사용자가 친 것.
    public let typed: String
    /// 되살린 원문의 소리. 뜻 아래에 작게 서서 무엇을 옮긴 것인지 말해 준다.
    public let kana: String
    /// 번역기에 넘길 원문. 한자를 살린다(`Array<Segment>.forTranslation`).
    public let forTranslation: String
    /// 번역기를 부르지 않아도 되는 뜻. 입력 전체를 사전이 한 낱말로 알 때와,
    /// 조각이 하나뿐이고 그 낱말에 한국어 뜻이 실려 있을 때다.
    public let knownMeaning: String?
    /// 조각이 둘 이상인가. 앱의 찾기 화면이 문장 머리줄을 세우는 기준과 같다.
    public let isSentence: Bool
    /// 낱말 하나일 때 그 갈래. 꼬리표(`명사` · `동사`)로 단다. 문장이면 nil.
    public let wordClass: WordClass?

    public init(typed: String, segments: [Segment]) {
        self.typed = typed
        // 통째로 찾은 것은 문장의 한 부분이 아니다 — 함께 이으면 원문이 두 번 적힌다.
        let parts = segments.filter { !$0.isWhole }.filter { !$0.results.isEmpty }
        let whole = segments.first(where: \.isWhole)
        kana = whole?.kana ?? parts.kana
        isSentence = parts.count >= 2
        wordClass = parts.count == 1 ? parts[0].results.first?.entry.wordClass : nil
        forTranslation = whole.map { [$0].forTranslation() } ?? parts.forTranslation()
        if let gloss = segments.wholeKoreanGloss {
            knownMeaning = gloss
        } else if parts.count == 1, let gloss = parts[0].results.first?.entry.koreanGloss,
                  !gloss.isEmpty {
            knownMeaning = gloss
        } else {
            knownMeaning = nil
        }
    }

    /// 사전에서 아무것도 못 찾았는가.
    public var isEmpty: Bool { kana.isEmpty }
}
