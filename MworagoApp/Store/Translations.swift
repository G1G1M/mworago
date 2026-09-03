import Foundation
import Observation
import MworagoCore

/// 옮긴 말을 모아 두는 곳.
///
/// **문장마다 세션을 열지 않는다.** 처음에는 문장이 바뀔 때마다 설정을 새로 만들어 세션을
/// 다시 열었는데, 실기기에서 그때마다 걸렸다. 세션을 여는 일이 번역 자체보다 무겁다.
/// 그래서 세션은 찾기 화면이 살아 있는 동안 열어 둔 채로 **옮길 것을 줄로 흘려보낸다.**
///
/// 세션은 화면과 함께 물러난다(`.translationTask` 가 취소된다). **줄은 그때 함께 죽으면
/// 안 된다** — 죽은 줄은 되살릴 수 없어서, 탭을 한 번 다녀오면 그 뒤로 아무것도 옮겨지지
/// 않았다. 줄은 세션이 돌아올 때마다 새로 열고, 답 못 받은 것을 새 줄로 옮겨 싣는다.
///
/// 한 번 옮긴 것은 다시 묻지 않는다. 글자를 지웠다가 도로 치면 이미 답이 여기 있다.
@Observable
@MainActor
final class Translations {

    /// 원문 → 옮긴 말.
    ///
    /// 화면이 지켜보는 것은 이것 하나다. 무엇을 물어보러 보냈는지·몇 번 실패했는지는
    /// 줄(`TranslationQueue`)이 맡는다 — 그쪽은 화면이 다시 그려질 일이 아니다.
    private var done: [String: String] = [:]

    /// 물어보러 보낸 것이 서는 줄.
    ///
    /// **세션이 볼 줄은 열 때마다 새로 낸다.** 예전에는 앱이 사는 동안 줄을 하나만 두고
    /// 세션이 그것을 읽게 했는데, 줄을 읽는 쪽은 화면에 매여 있다 —
    /// `.translationTask` 는 찾기 탭을 벗어나면 취소되고, `AsyncStream` 은 읽던 쪽이
    /// 취소되면 **줄 자체가 끝난다**(그 뒤의 `yield` 는 전부 `terminated` 로 돌아온다).
    /// 그래서 **탭을 한 번 다녀오면 그 뒤로는 어떤 문장도 옮겨지지 않았다.**
    /// 앱을 껐다 켜야 다시 됐다.
    private let queue = TranslationQueue()

    /// 이미 옮긴 말. 아직이면 nil — 그때는 부르는 쪽이 원문을 그대로 보여 준다.
    subscript(_ text: String) -> String? { done[text] }

    /// 세션이 지켜볼 줄을 연다. 부를 때마다 새로 열리고,
    /// **아직 답을 못 받은 것은 새 줄로 옮겨 실린다.**
    func openRequests() -> AsyncStream<[String]> { queue.open() }

    /// 옮겨 달라고 넣는다. 이미 옮긴 것과 물어보러 보낸 것은 줄이 거른다.
    func ask(_ texts: [String]) {
        queue.ask(texts.filter { done[$0] == nil })
    }

    /// 옮겨진 것을 받는다. 빈손으로 온 것도 **물음은 끝난 것**이다.
    func receive(_ pairs: [(source: String, target: String)]) {
        queue.answered(pairs.map(\.source))
        for pair in pairs where !pair.target.isEmpty {
            done[pair.source] = pair.target
        }
    }

    /// 못 옮긴 것. 다시 물어볼 만하면 줄에 도로 싣고 `true` 를 돌려준다.
    ///
    /// 번역기가 아직 준비되지 않아(언어팩을 내려받는 중) 실패하는 일은 실제로 있다.
    /// 세 번까지 다시 보내고, 그래도 안 되면 **물어본 표시를 지운다** —
    /// 표시만 남으면 사용자가 다시 쳐도 이미 물어본 것으로 걸러져 영영 안 뜬다.
    @discardableResult
    func failed(_ texts: [String]) -> Bool { queue.failed(texts) }
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
