import Foundation
@preconcurrency import Translation
import MworagoCore

/// 화면 없이 찾는 자리. 동작 버튼 · Siri · 단축어가 부른다.
///
/// 찾기 화면의 `SearchEngine` 은 화면에 매여 있다 — 메인 액터 위에 살고, 결과를 화면에
/// 그릴 상태로 들고 있는다. 앱이 화면 없이 깨어나 한 번 찾고 끝날 때는 그것을 세울
/// 까닭이 없다. 같은 사전과 같은 분절기를 쓰되 **뜻 한 줄만 돌려준다.**
///
/// 사전은 처음 부를 때 한 번 연다. 앱이 살아 있는 동안 다시 부르면 연 것을 그대로 쓴다.
actor QuickLookup {

    static let shared = QuickLookup()

    /// 작은 창에 올릴 것 — 뜻과, 그 뜻이 어디서 왔는지.
    struct Result: Sendable {
        let answer: QuickAnswer
        /// 한국어 뜻. 사전이 알면 그것이고, 아니면 번역기가 옮긴 것이다.
        /// 둘 다 없으면 nil — 언어팩이 없거나 번역기가 실패했다.
        let meaning: String?
        /// 뜻이 비었을 때 왜 비었는지 말하려고 든다.
        var pack: TranslationPack = .unknown
    }

    private var lexicon: Lexicon?
    private let cache = SearchCache()

    func look(_ typed: String) async throws -> Result {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Result(answer: QuickAnswer(typed: trimmed, segments: []), meaning: nil)
        }
        let lexicon = try opened()
        let segments = Segmenter.segment(trimmed, in: lexicon.dictionary,
                                         frequency: lexicon.frequency, cache: cache)
        let answer = QuickAnswer(typed: trimmed, segments: segments)
        if answer.isEmpty { return Result(answer: answer, meaning: nil) }
        if let known = answer.knownMeaning { return Result(answer: answer, meaning: known) }
        let pack = await Self.pack()
        guard pack == .ready else { return Result(answer: answer, meaning: nil, pack: pack) }
        return Result(answer: answer, meaning: await Self.translate(answer.forTranslation), pack: pack)
    }

    /// 기기의 번역기로 옮긴다.
    ///
    /// 찾기 화면은 `.translationTask` 로 세션을 여는데, 그것은 화면에 매달린 문이라 여기서는
    /// 쓸 수 없다. iOS 26 부터는 **이미 깔린 언어팩**으로 세션을 직접 열 수 있다. 언어팩이
    /// 없으면 내려받으라고 묻는 창을 띄울 자리가 없으므로 그냥 nil 을 돌려준다 —
    /// 그 안내는 앱 안의 찾기 화면이 이미 하고 있다.
    private static func translate(_ japanese: String) async -> String? {
        guard #available(iOS 26.0, *) else { return nil }
        let session = TranslationSession(installedSource: .japanese, target: .korean)
        let text = try? await session.translate(japanese).targetText
        return text?.isEmpty == false ? text : nil
    }

    /// 일→한 언어팩이 이 기기에 있는가. 앱의 찾기 화면이 묻는 것과 같은 물음이다.
    private static func pack() async -> TranslationPack {
        TranslationPack(await LanguageAvailability().status(from: .japanese, to: .korean))
    }

    private func opened() throws -> Lexicon {
        if let lexicon { return lexicon }
        let fresh = try Lexicon(locating: BundleResources())
        lexicon = fresh
        return fresh
    }
}
