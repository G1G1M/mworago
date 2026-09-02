import Foundation

/// 조각을 찾아본 결과를 재어 두는 곳.
///
/// **글자를 칠 때마다 문장 전체를 처음부터 다시 찾고 있었다.** 분절은 앞에서부터 모든
/// 끊는 자리를 재보므로, 열다섯 글자짜리 입력 하나에 조각 백 개를 찾는다. 그런데
/// 글자를 하나 더 치면 그 백 개가 고스란히 다시 계산된다 — `코노` 도 `에이가` 도
/// 이미 답을 아는 조각인데.
///
/// 재어 보니 열다섯 글자를 치는 동안 5.6초를 그렇게 썼다(마지막 한 글자에만 1.6초).
/// 조각의 답은 입력이 길어져도 달라지지 않으므로, 한 번 찾은 것은 들고 있으면 된다.
///
/// **여러 곳에서 함께 쓴다.** 찾는 일은 화면 밖에서 도는데 결과는 화면이 받으므로,
/// 자물쇠로 잠가 어느 쪽에서 들어와도 안전하게 한다 — 사전 색인과 같은 방식이다.
public final class SearchCache: @unchecked Sendable {

    private var store: [String: [SearchResult]] = [:]
    private let lock = NSLock()

    /// 담아 둘 조각 수의 상한.
    ///
    /// 문장 하나가 만드는 조각은 백 개 남짓이고, 사람이 이어서 치는 문장은 서로 겹친다.
    /// 그래도 한 자리에서 오래 쓰면 늘어나기만 하므로 선을 둔다. 넘으면 통째로 비운다 —
    /// 무엇을 버릴지 고르는 일이 아끼는 것보다 비싸고, 비워도 다시 채우면 그만이다.
    private static let limit = 4000

    public init() {}

    /// 찾아 둔 것이 있으면 그것을, 없으면 찾아서 담고 돌려준다.
    func result(for piece: String, find: () -> [SearchResult]) -> [SearchResult] {
        lock.lock()
        if let found = store[piece] {
            lock.unlock()
            return found
        }
        lock.unlock()

        // **찾는 동안에는 잠그지 않는다.** 이 일이 이 클래스에서 가장 오래 걸리는데,
        // 붙들고 있으면 다른 쪽이 그동안 캐시를 읽지도 못한다.
        let found = find()

        lock.lock()
        if store.count >= Self.limit { store.removeAll(keepingCapacity: true) }
        store[piece] = found
        lock.unlock()
        return found
    }

    /// 담아 둔 것을 모두 버린다. 사전이나 빈도가 바뀌면 답도 달라진다.
    public func clear() {
        lock.lock()
        store.removeAll(keepingCapacity: true)
        lock.unlock()
    }
}
