import Foundation

/// 활용형을 사전형으로 되돌린 결과.
public struct Deinflection: Sendable, Equatable {
    public let form: String    // 되돌린 형태
    public let rule: String?   // 어떤 활용이었나. nil이면 손대지 않은 원문
}

/// 활용형을 사전에서 찾을 수 있는 형태로 되돌린다.
///
/// JMdict는 사전형만 싣는다. `やめる`는 있어도 `やめろ`는 없다.
/// 그런데 애니 대사는 대부분 활용형이다 — 명령형("야메로!"), 과거형("요캇타"), て형("타스케테").
/// 사전을 날것으로 쓰면 앱이 정확히 노리는 문장에서 가장 많이 터진다.
///
/// 여기서도 원칙은 같다. **후보를 펼치고 고르는 일은 사전에 맡긴다.**
/// `った`가 う·つ·る 중 무엇에서 왔는지는 형태만 봐서 알 수 없으므로 셋 다 낸다.
public enum Deinflector {

    /// 5단 동사 명령형은 어미가 え단으로 바뀐다. 되돌리려면 う단으로 옮긴다.
    private static let eToU: [Character: Character] = [
        "え": "う", "け": "く", "げ": "ぐ", "せ": "す", "ぜ": "ず",
        "て": "つ", "で": "づ", "ね": "ぬ", "へ": "ふ", "べ": "ぶ",
        "ぺ": "ぷ", "め": "む", "れ": "る",
    ]

    /// (어미, 붙일 것들, 활용 이름). 어미를 떼고 각각을 붙인 형태가 후보가 된다.
    private static let rules: [(suffix: String, replacements: [String], name: String)] = [
        // 과거형 — 음편이 있는 5단이 먼저, 짧은 규칙이 뒤
        ("かった", ["い"],            "과거형"),   // い형용사: よかった → よい
        ("った",  ["う", "つ", "る"], "과거형"),
        ("いた",  ["く"],            "과거형"),
        ("いだ",  ["ぐ"],            "과거형"),
        ("んだ",  ["ぶ", "む", "ぬ"], "과거형"),
        ("した",  ["す"],            "과거형"),
        ("た",    ["る"],            "과거형"),   // 1단: つかれた → つかれる

        // て형
        ("って",  ["う", "つ", "る"], "て형"),
        ("いて",  ["く"],            "て형"),
        ("いで",  ["ぐ"],            "て형"),
        ("んで",  ["ぶ", "む", "ぬ"], "て형"),
        ("して",  ["す"],            "て형"),
        ("て",    ["る"],            "て형"),

        // 그 밖
        ("ろ",    ["る"],            "명령형"),   // 1단: やめろ → やめる
        ("ない",  ["る"],            "부정형"),
        ("ます",  ["る"],            "정중형"),
        ("で",    [""],              "조사 で"),  // まじで → まじ
    ]

    /// 이보다 짧은 말은 건드리지 않는다. "て" 한 글자를 て형으로 보면 오탐만 는다.
    private static let minimumLength = 2

    /// 되돌린 형태들. 첫 번째는 언제나 원문 그대로다(사전에 활용형이 실린 경우가 있다).
    public static func candidates(for kana: String) -> [Deinflection] {
        var results = [Deinflection(form: kana, rule: nil)]
        guard kana.count >= minimumLength else { return results }

        var seen: Set<String> = [kana]
        func add(_ form: String, _ rule: String) {
            guard form.count >= 1, seen.insert(form).inserted else { return }
            results.append(Deinflection(form: form, rule: rule))
        }

        for rule in rules where kana.hasSuffix(rule.suffix) {
            let stem = String(kana.dropLast(rule.suffix.count))
            guard !stem.isEmpty else { continue }
            for replacement in rule.replacements {
                add(stem + replacement, rule.name)
            }
        }

        // 5단 명령형: 마지막 글자만 え단 → う단으로 옮긴다
        if let last = kana.last, let restored = eToU[last] {
            add(String(kana.dropLast()) + String(restored), "명령형")
        }

        return results
    }
}
