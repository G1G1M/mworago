import Foundation

/// 옮겨 달라고 보낼 것이 서는 줄.
///
/// 앱은 번역 세션을 **언어쌍마다 하나만** 열어 둔다 — 세션을 여는 일이 옮기는 일보다
/// 무거워서, 문장이 바뀔 때마다 열면 실기기에서 걸린다. 그래서 세션은 열어 둔 채로
/// 옮길 것을 이 줄로 흘려보낸다.
///
/// **줄을 붙들어 두지 않고 열 때마다 새로 낸다.** 줄을 읽는 쪽은 화면에 매여 있어서
/// (`.translationTask` 는 뷰가 사라지면 취소된다) 찾기 탭을 벗어나면 읽던 태스크가
/// 없어지는데, `AsyncStream` 은 읽던 쪽이 사라지면 **줄 자체가 끝난다.** 한 번 끝난 줄은
/// 되살릴 수 없고 그 뒤로 넣는 것은 조용히 버려지므로, 줄을 하나만 두면 탭을 한 번
/// 다녀온 뒤로는 어떤 문장도 영영 옮겨지지 않았다.
///
/// 답을 못 받은 것은 새 줄로 옮겨 싣는다. 그래야 줄이 끊긴 사이에 물어본 것도,
/// 줄이 열리기 전(세션을 여는 사이)에 물어본 것도 잃지 않는다.
@MainActor
public final class TranslationQueue {

    /// 물어본 채 아직 답이 오지 않은 것.
    public private(set) var pending: Set<String> = []
    /// 몇 번째 보내는 중인가. 답도 실패도 오지 않은 것은 여기 없다(첫 번째로 친다).
    private var attempts: [String: Int] = [:]
    private var line: AsyncStream<[String]>.Continuation?
    /// 한 문장을 몇 번까지 보내 보는가.
    private let tries: Int

    public init(tries: Int = 3) {
        self.tries = tries
    }

    /// 세션이 지켜볼 줄을 연다. **부를 때마다 새로 연다.**
    ///
    /// 앞의 줄은 닫는다 — 읽던 쪽이 이미 사라졌거나, 사라지지 않았다면 그쪽 세션도
    /// 함께 물러나는 참이다. 읽는 쪽이 둘이면 같은 문장이 두 번 옮겨진다.
    public func open() -> AsyncStream<[String]> {
        line?.finish()
        // 앞의 실패는 그 세션의 사정이었다. 새 세션에게 앞 세션의 빚을 지우지 않는다.
        attempts.removeAll()
        let stream = AsyncStream<[String]>(bufferingPolicy: .unbounded) { line = $0 }
        if !pending.isEmpty {
            // 차례를 정해 둔다. 무엇이 먼저 갈지는 중요하지 않지만, 같은 자리에서 늘
            // 같은 차례여야 무엇이 잘못됐을 때 되짚을 수 있다.
            line?.yield(pending.sorted())
        }
        return stream
    }

    /// 줄에 싣는다. **이미 물어본 것은 싣지 않는다** — 답을 기다리는 중이기 때문이다.
    /// 실제로 실은 것을 돌려준다.
    @discardableResult
    public func ask(_ texts: [String]) -> [String] {
        var fresh: [String] = []
        for text in texts where !text.isEmpty && !pending.contains(text) && !fresh.contains(text) {
            fresh.append(text)
        }
        guard !fresh.isEmpty else { return [] }
        pending.formUnion(fresh)
        // 줄이 아직 없거나 이미 끝났으면 여기서는 버려진다. 그래도 `pending` 에 남으므로
        // 다음에 줄을 열 때 함께 실려 간다.
        line?.yield(fresh)
        return fresh
    }

    /// 답이 온 것. 옮겨졌든 빈손이든 **물음은 끝났다.**
    public func answered(_ texts: [String]) {
        pending.subtract(texts)
        for text in texts { attempts[text] = nil }
    }

    /// 못 옮긴 것. 다시 물어볼 만하면 줄에 도로 싣고 `true` 를 돌려준다.
    ///
    /// **놓아줄 때는 물어본 표시도 지운다.** 표시만 남고 답이 오지 않으면 그 문장은
    /// 영영 뜨지 않는다 — 사용자가 다시 쳐도 이미 물어본 것으로 걸러지기 때문이다.
    @discardableResult
    public func failed(_ texts: [String]) -> Bool {
        var again: [String] = []
        for text in texts where pending.contains(text) {
            let sent = attempts[text] ?? 1
            if sent < tries {
                attempts[text] = sent + 1
                again.append(text)
            } else {
                pending.remove(text)
                attempts[text] = nil
            }
        }
        guard !again.isEmpty else { return false }
        line?.yield(again)
        return true
    }
}
