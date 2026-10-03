import Foundation

/// 넘겨 보는 화면의 셈 — 지금 장 찾기와 끝에서 처음으로 돌기.
///
/// 연습 · 가나 익히기 · 낱말 상세 · 글자 상세가 같은 셈을 각자 적고 있었다. 화면은
/// "어느 장을 보고 있는가"를 id 하나로만 들고, 장의 자리는 그때그때 이 셈으로 찾는다.
extension Array where Element: Identifiable {

    /// 보고 있는 장. 그 장이 사라졌으면(옮겨 가거나 빠졌으면) 첫 장이다.
    public func page(_ id: Element.ID?) -> Element? {
        first { $0.id == id } ?? first
    }

    /// 보고 있는 장이 몇 번째인가. **찾았을 때만 말한다** — 못 찾았는데 0 을 돌려주면
    /// "1 / 4" 가 사라진 장을 가리킨다.
    public func pageIndex(_ id: Element.ID?) -> Int? {
        id.flatMap { id in firstIndex { $0.id == id } }
    }

    /// `offset` 만큼 넘긴 장. 끝에서 처음으로, 처음에서 끝으로 돈다 —
    /// `다음` 과 `이전` 이 짝을 이룬다. 보던 장이 없으면 첫 장에서 센다.
    public func pageID(from id: Element.ID?, by offset: Int) -> Element.ID? {
        guard !isEmpty else { return nil }
        let start = pageIndex(id) ?? 0
        let wrapped = ((start + offset) % count + count) % count
        return self[wrapped].id
    }
}
