import Testing
import Foundation
@testable import MworagoCore

/// 옮겨 달라고 보낸 것이 서는 줄.
///
/// **줄은 다시 열려야 한다.** 앱은 번역 세션을 하나만 열어 두고(여는 일이 옮기는 일보다
/// 무겁다) 옮길 것을 줄로 흘려보내는데, 그 줄을 읽는 쪽은 화면에 매여 있다 —
/// 찾기 탭을 벗어나면 읽던 태스크가 취소된다. `AsyncStream` 은 읽던 쪽이 사라지면
/// **줄 자체가 끝나** 되살릴 수 없고, 그 뒤로 넣는 것은 조용히 버려진다.
///
/// 그래서 줄을 붙들어 두지 않고 열 때마다 새로 낸다. 답을 못 받은 것은 새 줄로 옮겨 싣는다.
@Suite("옮길 것이 서는 줄")
@MainActor
struct TranslationQueueTests {

    @Test("줄을 읽던 쪽이 사라져도, 다시 열면 답 못 받은 것이 새 줄에 실린다")
    func 다시열기() async {
        let queue = TranslationQueue()
        let first = queue.open()
        _ = queue.ask(["痛い"])

        // 탭을 옮기면 `.translationTask` 가 취소되어 읽던 쪽이 사라진다.
        let reader = Task { for await _ in first { break } }
        _ = await reader.value

        // 앱이 사는 동안 줄을 하나만 두던 때에는 여기서 끝이었다 — 다시 물어도
        // 넣을 곳이 없고, 새로 읽으려 해도 곧바로 끝났다.
        var line = queue.open().makeAsyncIterator()
        #expect(await line.next() == ["痛い"])
    }

    @Test("줄이 죽어 있는 사이에 물어본 것도 새 줄에 실린다")
    func 줄없을때물어보기() async {
        let queue = TranslationQueue()
        let first = queue.open()
        let reader = Task { for await _ in first { } }
        reader.cancel()
        _ = await reader.value

        _ = queue.ask(["約束"])

        var line = queue.open().makeAsyncIterator()
        #expect(await line.next() == ["約束"])
    }

    @Test("줄이 열리기 전에 물어본 것은 첫 줄에 실린다")
    func 열리기전에() async {
        // 세션을 여는 데(언어를 확인하고 언어팩을 챙기는 데) 시간이 걸린다.
        // 그 사이에 친 문장이 조용히 사라지면 그 문장만 영영 안 뜬다.
        let queue = TranslationQueue()
        _ = queue.ask(["大丈夫"])

        var line = queue.open().makeAsyncIterator()
        #expect(await line.next() == ["大丈夫"])
    }

    @Test("같은 것을 두 번 묻지 않는다")
    func 중복() {
        let queue = TranslationQueue()
        #expect(queue.ask(["痛い", "約束"]) == ["痛い", "約束"])
        #expect(queue.ask(["痛い"]).isEmpty)
        // 빈 것은 물어볼 것이 아니다.
        #expect(queue.ask([""]).isEmpty)
    }

    @Test("답이 오면 줄에서 빠진다")
    func 답받기() async {
        let queue = TranslationQueue()
        _ = queue.ask(["痛い"])
        queue.answered(["痛い"])
        #expect(queue.pending.isEmpty)

        // 답을 받은 것은 새 줄에 다시 싣지 않는다. 다시 열었을 때 첫 줄에 오는 것은
        // 그 뒤에 물어본 것이어야 한다.
        var line = queue.open().makeAsyncIterator()
        _ = queue.ask(["約束"])
        #expect(await line.next() == ["約束"])
    }

    @Test("못 옮긴 것은 같은 줄로 다시 간다")
    func 실패재시도() async {
        // 언어팩을 아직 내려받는 중이면 첫 물음이 빈손으로 돌아온다.
        // 그 한 번 때문에 문장이 영영 안 뜨는 것은 사용자가 알 길이 없다.
        let queue = TranslationQueue()
        var line = queue.open().makeAsyncIterator()
        _ = queue.ask(["痛い"])
        #expect(await line.next() == ["痛い"])

        #expect(queue.failed(["痛い"]) == true)
        #expect(await line.next() == ["痛い"])
    }

    @Test("세 번까지만 다시 묻고 놓아준다")
    func 재시도한도() {
        let queue = TranslationQueue(tries: 3)
        _ = queue.ask(["痛い"])
        #expect(queue.failed(["痛い"]) == true)    // 두 번째
        #expect(queue.failed(["痛い"]) == true)    // 세 번째
        #expect(queue.failed(["痛い"]) == false)   // 그만
        // **놓아준다는 것은 다시 물어볼 수 있다는 뜻이다.** 물어본 것으로 표시된 채
        // 남으면 그 문장은 영영 걸러진다 — 사용자가 다시 쳐도 마찬가지다.
        #expect(queue.pending.isEmpty)
        #expect(queue.ask(["痛い"]) == ["痛い"])
    }

    @Test("줄을 새로 열면 실패한 횟수는 잊는다")
    func 새줄새기회() {
        // 앞의 실패는 그 세션의 사정이었다. 새 세션에게 앞 세션의 빚을 지우지 않는다.
        let queue = TranslationQueue(tries: 3)
        _ = queue.ask(["痛い"])
        #expect(queue.failed(["痛い"]) == true)
        #expect(queue.failed(["痛い"]) == true)

        _ = queue.open()
        #expect(queue.failed(["痛い"]) == true)
        #expect(queue.failed(["痛い"]) == true)
        #expect(queue.failed(["痛い"]) == false)
    }
}
