import Foundation

/// 최근에 찾은 소리 몇 개. **기기 안에만 둔다** — 어디로도 보내지 않는다.
///
/// 찾기 빈 화면에는 안내문과 입력 칸뿐이었다. 그런데 이 앱을 쓰는 자리는 영상을 보다
/// 멈춘 순간이라, 같은 소리를 몇 분 뒤에 다시 찾는 일이 잦다(같은 화에서 같은 말이
/// 되풀이된다). 다시 치게 하지 않고 눌러서 돌아가게 한다.
///
/// 적는 꼴은 한 줄에 하나, 가장 최근 것이 위다.
public enum RecentQueries {
    /// 몇 개까지 남기는가. 키보드가 올라온 좁은 자리에도 다 들어가야 한다.
    public static let limit = 5

    /// `query` 를 맨 위에 올린다. 이미 있으면 그 자리에서 빼서 올리고, 넘치면 오래된 것을 버린다.
    /// 띄어쓰기는 고르지 않는다 — `다이 죠부` 와 `다이죠부` 는 같은 소리다.
    public static func adding(_ query: String, to list: [String]) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return list }
        let key = squeezed(trimmed)
        return Array(([trimmed] + list.filter { squeezed($0) != key }).prefix(limit))
    }

    /// 하나만 지운다. 띄어쓰기는 가리지 않는다.
    public static func removing(_ query: String, from list: [String]) -> [String] {
        let key = squeezed(query)
        return list.filter { squeezed($0) != key }
    }

    public static func decode(_ text: String?) -> [String] {
        (text ?? "").split(separator: "\n").map(String.init).prefix(limit).map { $0 }
    }

    public static func encode(_ list: [String]) -> String? {
        list.isEmpty ? nil : list.joined(separator: "\n")
    }

    private static func squeezed(_ text: String) -> String { text.filter { !$0.isWhitespace } }
}
