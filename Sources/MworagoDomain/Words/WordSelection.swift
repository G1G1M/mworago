import Foundation

/// 낱말을 골라 두고 한꺼번에 옮기거나 지우는 손 — 책장의 `모두` 목록과 묶음 화면이 같이 쓴다.
///
/// 고른 것은 낱말 자체가 아니라 `id` 로 든다 — 옮기고 나면 낱말의 값이 바뀌는데,
/// 값으로 들고 있으면 옮긴 뒤에 같은 것을 못 알아본다.
public struct WordSelection: Equatable, Sendable {

    /// 고르는 손이 얹혔는가.
    public private(set) var isActive = false
    private var ids: Set<String> = []

    public init() {}

    public var count: Int { ids.count }
    public func contains(_ id: String) -> Bool { ids.contains(id) }

    /// 손을 얹는다. `picking` 을 주면 그것들을 고른 채로 시작한다(실행 인자로 화면을 띄울 때).
    public mutating func begin(picking: [String] = []) {
        isActive = true
        ids = Set(picking)
    }

    public mutating func toggle(_ id: String) {
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
    }

    /// 목록을 다 골랐는가. **빈 목록은 다 고른 것이 아니다** — 고를 것이 없다.
    public func allPicked(of list: [String]) -> Bool {
        !list.isEmpty && ids.count == list.count && ids.isSuperset(of: list)
    }

    /// 다 골랐으면 다 풀고, 아니면 다 고른다.
    public mutating func toggleAll(_ list: [String]) {
        ids = allPicked(of: list) ? [] : Set(list)
    }

    /// 손을 뗀다. 고른 것도 함께 비운다 — 다음에 켤 때 지난 손이 남아 있으면 안 된다.
    public mutating func end() {
        isActive = false
        ids = []
    }

    /// 고른 것을 목록의 차례대로 꺼낸다.
    public func picked<W: Identifiable>(in words: [W]) -> [W] where W.ID == String {
        words.filter { ids.contains($0.id) }
    }
}
