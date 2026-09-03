import Foundation
import MworagoDomain

/// 문장 뜻을 모델에 물을 때 넘길 재료.
///
/// **모델에게 맨몸으로 시키지 않는다.** 온디바이스 모델은 3B 남짓이라 일본어 문장을
/// 통째로 던지면 힘에 부친다. 그런데 우리는 이미 그 문장을 뜯어 놓았다 — 어디서 끊기는지,
/// 낱말마다 무슨 뜻이고 품사가 무엇이며 어떻게 활용됐는지. 그 재료를 얹어 주면
/// 모델이 할 일은 **옮기는 것이 아니라 이어 붙이는 것**에 가까워진다.
///
/// 낱말 뜻을 구울 때 배운 것이 그대로 여기 적용된다. 품사를 알려 주지 않으면
/// `思う`(to think)가 "생각하다"가 아니라 "생각"으로 돌아왔다. 문장에서도 같은 일이 난다.
///
/// 이 자리를 앱이 아니라 여기 둔 것은 **재료가 순수 로직이기 때문**이다. 모델을 부르는 일은
/// 기기와 OS 판을 타지만, 무엇을 물을지는 타지 않는다. 그래야 테스트로 고정된다.
public enum SentencePrompt {

    /// 모델에 얹는 지시.
    ///
    /// **지어내지 말라고 못 박는 자리다.** 이 앱은 사전에 근거가 있는 것만 말해 왔고,
    /// 모델이 옮긴 한 줄은 그 원칙에서 유일하게 벗어나는 것이라 고삐가 필요하다.
    public static let instructions = """
        너는 일본어를 한국어로 옮긴다.

        - 한국어 한 문장만 적는다. 설명하거나 덧붙이지 않는다.
        - 주어진 낱말 뜻을 재료로 쓴다. 재료에 없는 말을 지어내지 않는다.
        - 말투와 시제는 활용에 적힌 것을 따른다.
        - 뜻이 영어로 적혀 있으면 한국어로 옮겨 쓴다. 영어를 그대로 적지 않는다.
        - 사전에 없다고 적힌 조각은 소리만 아는 것이다. 억지로 옮기지 않는다.
        """

    /// 문장 하나를 묻는 재료. 물을 것이 없으면 nil.
    ///
    /// **조각이 하나뿐이면 묻지 않는다.** 낱말 하나는 카드에 뜬 뜻이 이미 답이라,
    /// 모델을 부르는 것은 몇 초와 배터리를 쓰고 같은 말을 다시 듣는 일이다.
    public static func materials(for segments: [Segment]) -> String? {
        // 통째로 찾은 것은 문장의 한 부분이 아니라 문장 전체를 한 번 더 적은 것이다.
        let parts = segments.filter { !$0.isWhole }
        guard parts.count >= 2 else { return nil }

        var lines = [
            "일본어: \(parts.japanese)",
            "읽기: \(parts.kana)",
            "",
            "낱말:",
        ]
        lines.append(contentsOf: parts.map(line(for:)))
        return lines.joined(separator: "\n")
    }

    /// 재료에 물음까지 붙인 것. 그대로 모델에 넘긴다.
    public static func prompt(for segments: [Segment]) -> String? {
        materials(for: segments).map { $0 + "\n\n이 문장을 한국어 한 문장으로 옮겨라." }
    }

    /// 낱말 한 줄.
    ///
    /// `頭(あたま) · 명사 · 머리` 처럼 적는다. 품사를 모르면 그 칸을 비운다 —
    /// 조사에 붙일 품사 이름이 없고, 뜻 자리에 이미 기능이 적혀 있다(`が` → `~이, ~가`).
    private static func line(for segment: Segment) -> String {
        // **못 찾은 것은 못 찾았다고 적는다.** 여기서 지어내면 문장 전체가 조용히 틀어진다.
        guard let top = segment.results.first else {
            return "\(segment.hangul) · 사전에 없다"
        }

        // 표기가 읽기와 같으면 괄호에 같은 글자를 한 번 더 적을 이유가 없다.
        let word = top.headword == top.reading ? top.reading : "\(top.headword)(\(top.reading))"
        var fields = [word]
        if let partOfSpeech = top.entry.wordClass.koreanName { fields.append(partOfSpeech) }
        fields.append(gloss(of: top.entry))
        // 사전형만 넘기면 시제와 말투가 사라진다 — 痛かった 가 "아프다"로 옮겨진다.
        if let rule = top.deinflection {
            fields.append(rule)
            return "\(top.matchedKana) ← " + fields.joined(separator: " · ")
        }
        return fields.joined(separator: " · ")
    }

    /// 재료에 실을 뜻 하나.
    ///
    /// **여럿을 늘어놓으면 모델이 아무거나 집는다.** 彼 의 뜻을 "그, 남자친구" 로 줬더니
    /// `彼は…しゃべらされた` 가 "남자친구는 그들에게 모두 대화했다" 로 돌아왔다.
    /// 어느 뜻인지 고르는 일은 문맥이 있어야 하는 일이고 아직 우리가 못 한다.
    /// 그러면 **사전이 먼저 적은 것**을 준다 — 그것이 그 낱말의 주된 뜻이다.
    ///
    /// 괄호에 든 것도 뺀다. 한국어 뜻이 없는 낱말은 영어가 그대로 실리는데, 그 안에 학명이
    /// 들어 있으면 통째로 베껴 온다 — `red-berried elder (Sambucus racemosa subsp.
    /// sieboldiana)` 가 답에 그대로 나왔다.
    private static func gloss(of entry: DictEntry) -> String {
        let text = entry.koreanGloss ?? entry.glosses.first ?? ""
        // **기능어는 자르지 않는다.** 조사의 `~이, ~가` 는 뜻이 둘인 것이 아니라
        // 한 자리를 한국어로 적는 두 가지 꼴이다. 여기서 자르면 재료가 반토막 난다.
        guard entry.wordClass.isTranslatable else {
            return withoutParentheses(text).trimmingCharacters(in: .whitespaces)
        }
        // 한국어 뜻은 쉼표로, 영어 뜻은 항목으로 갈려 있다. 어느 쪽이든 첫 것만 쓴다.
        let first = entry.koreanGloss == nil ? text
                                             : (text.split(separator: ",").first.map(String.init) ?? text)
        return withoutParentheses(first).trimmingCharacters(in: .whitespaces)
    }

    /// 괄호와 그 안의 것을 지운다. 여는 괄호를 못 닫으면 거기서 끊는다.
    private static func withoutParentheses(_ text: String) -> String {
        var result = ""
        var depth = 0
        for character in text {
            switch character {
            case "(", "（": depth += 1
            case ")", "）": depth = max(0, depth - 1)
            default: if depth == 0 { result.append(character) }
            }
        }
        return result
    }
}
