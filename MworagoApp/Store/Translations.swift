import Foundation
import Observation

/// 옮긴 말을 모아 두는 곳.
///
/// **세션은 하나만 연다.** 처음에는 문장이 바뀔 때마다 설정을 새로 만들어 세션을 다시 열었는데,
/// 실기기에서 그때마다 걸렸다. 세션을 여는 일이 번역 자체보다 무겁다.
/// 그래서 세션은 앱이 사는 동안 하나만 두고, **옮길 것을 여기로 흘려보낸다.**
///
/// 한 번 옮긴 것은 다시 묻지 않는다. 글자를 지웠다가 도로 치면 이미 답이 여기 있다.
@Observable
@MainActor
final class Translations {

    /// 원문 → 옮긴 말.
    private var done: [String: String] = [:]
    /// 물어보러 보낸 것. 같은 것을 두 번 보내지 않으려고 센다.
    private var asked: Set<String> = []

    /// 세션이 지켜보는 줄. 여기 넣으면 옮겨져서 `done` 에 담긴다.
    ///
    /// 세션은 화면 밖에서 도는 자리라 이 줄도 그쪽에서 읽을 수 있어야 한다.
    nonisolated let requests: AsyncStream<[String]>
    private let inbox: AsyncStream<[String]>.Continuation

    init() {
        var inbox: AsyncStream<[String]>.Continuation!
        // **하나도 버리지 않는다.** 열여섯 개까지만 담다가 넘치면 오래된 것을 버리게 해
        // 두었는데, 세션이 열리기 전에(언어를 확인하는 사이) 쌓인 것이 조용히 사라졌다.
        // 버려진 것은 물어본 것으로 표시된 채라 다시 묻지도 않는다 — 그 문장은 영영 안 뜬다.
        requests = AsyncStream(bufferingPolicy: .unbounded) { inbox = $0 }
        self.inbox = inbox
    }

    /// 이미 옮긴 말. 아직이면 nil — 그때는 부르는 쪽이 원문을 그대로 보여 준다.
    subscript(_ text: String) -> String? { done[text] }

    /// 옮겨 달라고 넣는다. 이미 옮겼거나 물어보러 보낸 것은 거른다.
    func ask(_ texts: [String]) {
        let fresh = texts.filter { !$0.isEmpty && done[$0] == nil && !asked.contains($0) }
        guard !fresh.isEmpty else { return }
        asked.formUnion(fresh)
        inbox.yield(fresh)
    }

    /// 옮겨진 것을 받는다.
    func receive(_ pairs: [(source: String, target: String)]) {
        for pair in pairs {
            asked.remove(pair.source)
            guard !pair.target.isEmpty else { continue }
            done[pair.source] = pair.target
        }
    }

    /// 못 옮긴 것을 **물어보지 않은 것으로 되돌린다.**
    ///
    /// 물어봤다는 표시만 남고 답이 오지 않으면 그 말은 영영 뜨지 않는다 —
    /// 다음에 같은 문장을 쳐도 이미 물어본 것으로 걸러지기 때문이다.
    /// 번역기가 아직 준비되지 않아 한 번 실패하는 일은 실제로 있으므로,
    /// 실패는 **기억하지 않는 편**이 맞다.
    func forget(_ texts: [String]) {
        asked.subtract(texts)
    }
}

/// 옮기는 자리 둘을 한데 둔다.
///
/// **언어쌍마다 세션이 따로다.** 문장은 일본어에서 오고(`頭が痛い`) 낱말 뜻은 영어에서 온다
/// (`corner · edge`). 한 세션에 섞어 넣으면 영어를 일본어로 여기고 옮기려 든다.
@Observable
@MainActor
final class TranslationDesk {
    /// 일본어 문장 → 한국어.
    let japanese = Translations()
    /// 영어 뜻 → 한국어. 사전에 한국어 뜻이 없는 낱말이 여기로 온다.
    ///
    /// 뜻은 미리 구워서 싣지만 22,610 개까지가 지금 자리고, 나머지는 영어로 남아 있다.
    /// 굽기가 닿지 않은 낱말을 화면에서 만난 그 자리에서 메운다.
    let english = Translations()
}
