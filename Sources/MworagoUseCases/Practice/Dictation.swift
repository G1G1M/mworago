import Foundation
import MworagoDomain

/// 받아쓰기 — 담은 낱말의 소리를 듣고 한글로 쳐 본 것을 본다.
///
/// **맞았다 틀렸다를 가리지 않는다.** 한글로 일본어를 적는 정답은 하나가 아니다 —
/// `다이죠부` 도 `다이조부` 도 같은 낱말에 닿는다. 그래서 묻는 것은 하나뿐이다:
/// **그렇게 쳐도 이 앱이 그 낱말을 찾아 주는가.** 찾아 주면 이 사람의 귀는 이미 쓸 만하다.
///
/// 기록은 남기지 않는다. 연습은 채점하지 않는다는 원칙(`PracticeView`)을 그대로 따른다 —
/// 그 자리에서 한 번 알려 주고 끝난다.
public enum Dictation {

    public enum Verdict: Equatable, Sendable {
        /// 그렇게 쳐도 이 낱말에 닿는다.
        case reached
        /// 한 글자만 다르게 들었다 — 그 글자를 고친 한글과 무엇이 달랐는지.
        case close(hangul: String, change: SoundAlike.Change)
        /// 닿지 않는다.
        case missed
        /// 아무것도 안 쳤거나 한글이 아니다.
        case empty
    }

    /// `typed` 로 찾아도 `reading` 에 닿는가.
    ///
    /// 사전을 찾지 않고 **가나 후보만 맞대 본다.** 찾기 화면은 같은 후보를 사전에 대어
    /// 줄을 세우는데, 여기서는 정답 낱말을 이미 알고 있으므로 후보 안에 그 읽기가 있는지만
    /// 보면 된다 — 사전을 열지 않아도 되고, 순위에서 밀린 것까지 「닿았다」고 친다.
    /// 순위는 사전이 정할 일이지 이 사람의 귀가 틀린 것이 아니기 때문이다.
    ///
    /// `alsoAccepts` 는 담을 때 이 사람이 실제로 친 한글처럼, 이미 닿는다고 알려진 소리다.
    public static func check(_ typed: String, reading: String, alsoAccepts: [String] = []) -> Verdict {
        let hangul = String(typed.filter { !$0.isWhitespace })
        guard !hangul.isEmpty, HangulSyllable.decompose(hangul) != nil else { return .empty }
        if reaches(hangul, reading: reading, alsoAccepts: alsoAccepts) { return .reached }
        for (fixed, change) in SoundAlikes.neighbors(of: hangul, voicingOnly: false)
        where reaches(fixed, reading: reading, alsoAccepts: alsoAccepts) {
            return .close(hangul: fixed, change: change)
        }
        return .missed
    }

    static func reaches(_ hangul: String, reading: String, alsoAccepts: [String]) -> Bool {
        if alsoAccepts.contains(hangul) { return true }
        // 쓰는 대로와 읽는 대로가 갈리는 끝자리 조사(`こんにちは` 의 は)는 읽는 대로도 받는다.
        var targets: Set<String> = [KanaTable.lookupKey(reading)]
        if reading.hasSuffix("は") { targets.insert(KanaTable.lookupKey(String(reading.dropLast()) + "わ")) }
        if reading.hasSuffix("へ") { targets.insert(KanaTable.lookupKey(String(reading.dropLast()) + "え")) }
        return Transliterator.kanaCandidates(for: hangul).contains { targets.contains(KanaTable.lookupKey($0)) }
    }
}
