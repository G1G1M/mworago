#if canImport(FoundationModels)
import Foundation
import FoundationModels
import MworagoDomain
import MworagoUseCases

/// 모델이 돌려줄 문장 하나.
///
/// **한 칸짜리 구조로 받는다.** 그냥 문자열로 받으면 그 안에 무엇이든 들어온다 —
/// 낱말 뜻을 구울 때 "무기를 가지고 있는 것과 같이 목표로 삼다– 어떤 것을..." 이
/// 통째로 돌아온 적이 있다. 칸을 못 박으면 형식이 프롬프트가 아니라 **구조**로 강제된다.
@available(iOS 26.0, macOS 26.0, *)
@Generable
public struct SentenceTranslation {
    @Guide(description: """
        한국어 한 문장. 주어진 낱말 뜻으로 이어 붙인 것이다.
        설명하거나 덧붙이지 않는다. 일본어를 그대로 옮겨 적지 않는다.
        """)
    public var korean: String
}

/// 문장 뜻을 온디바이스 모델에게 묻는다.
///
/// **낱말이 아니라 문장에만 쓴다.** 낱말 뜻은 미리 구워서 실을 수 있고 실제로 그렇게 했다.
/// 문장은 조합이 무한해서 구울 수가 없다 — 여기가 모델이 유일하게 필요한 자리다.
///
/// 이 길은 한 번 막혀 본 적이 있다. 낱말 뜻을 이 모델로 구우려다 한국어가 지원 언어에서
/// 빠져 있고(`unsupportedLanguageOrLocale` 185건) 죽음·폭력이 든 말이 막혀
/// (`guardrailViolation` 2,557건) EXAONE 으로 갈아탔다. 문장에서도 같은 벽을 만날 수 있는데,
/// **막히면 조용히 없던 일이 된다.** 화면에 사정을 늘어놓지 않는다 —
/// 애니 대사를 찾는 사람은 그 사정을 자주 보게 될 테니까.
@available(iOS 26.0, macOS 26.0, *)
public enum SentenceTranslator {

    /// 옮기는 일에 맞춘 모델.
    ///
    /// **기본 가드레일은 이 일에 너무 좁다.** 첫 삽에서 `何をしているの`("뭐 하고 있어?")가
    /// 막혔다 — 위험한 말이 한 글자도 없는 문장이다. 낱말을 구울 때 죽음·폭력이 든 말이
    /// 2,557건 막힌 것과는 결이 다르다. 그때는 막힌 이유라도 짐작이 갔다.
    ///
    /// `permissiveContentTransformations` 는 애플이 **옮기고 고쳐 쓰는 일**을 위해 내놓은
    /// 자리다. 우리가 하는 일이 정확히 그것이다 — 사용자가 친 문장을 지어내지 않고 옮긴다.
    /// 무엇이든 통과시키는 문이 아니라, 만들어 내는 일과 옮기는 일을 갈라 보는 문이다.
    private static let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)

    /// 이 기기에서 물어볼 수 있는가.
    ///
    /// Apple Intelligence 를 지원하지 않는 기기가 있고, 지원해도 꺼 두었거나
    /// 모델을 아직 내려받는 중일 수 있다. 어느 쪽이든 **기능이 없는 것**이지 실패가 아니다.
    public static var isAvailable: Bool {
        if case .available = model.availability { return true }
        return false
    }

    /// 문장 뜻 한 줄. 물을 것이 없으면 nil.
    ///
    /// **세션은 문장마다 새로 연다.** 하나를 계속 쓰면 주고받은 것이 이력으로 쌓여
    /// 얼마 못 가 컨텍스트가 넘친다(낱말을 구울 때는 세 번째에 이미 4,090/4,096 이었다).
    /// 문장 하나를 옮기는 일은 앞 문장과 아무 관계가 없다.
    ///
    /// **막히면 다시 묻는다.** 가드레일은 같은 문장에 같은 답을 주지 않는다 —
    /// `何をしているの`("뭐 하고 있어?")가 두 번 막히고 세 번째에 통과했다.
    /// 무엇이 막히는지에 규칙이 없으니 판정 자체가 흔들린다고 보는 편이 맞고,
    /// 그렇다면 한 번 막혔다고 없는 뜻으로 치는 것은 이르다.
    public static func translate(_ segments: [Segment], attempts: Int = 3) async throws -> String? {
        guard let prompt = SentencePrompt.prompt(for: segments) else { return nil }
        var lastError: Error?
        for _ in 0..<max(1, attempts) {
            do {
                let session = LanguageModelSession(model: Self.model,
                                                   instructions: SentencePrompt.instructions)
                let response = try await session.respond(to: prompt, generating: SentenceTranslation.self)
                let korean = response.content.korean.trimmingCharacters(in: .whitespacesAndNewlines)
                if !korean.isEmpty { return korean }
            } catch let error as LanguageModelSession.GenerationError {
                // 막힌 것만 다시 묻는다. 컨텍스트가 넘쳤거나 모델을 못 쓰는 것은 다시 물어도 같다.
                guard case .guardrailViolation = error else { throw error }
                lastError = error
                try Task.checkCancellation()
            }
        }
        if let lastError { throw lastError }
        return nil
    }
}
#endif
