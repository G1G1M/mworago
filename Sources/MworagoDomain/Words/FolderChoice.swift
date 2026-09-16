import Foundation

/// 담기 판에서 지금 어디가 골라져 있는가, 그리고 `저장` 을 누르면 어디에 담기는가.
///
/// **이름 칸에 친 글자도 고른 것이다.** 한때는 점이 찍힌 줄만 보고 담았다. 새 묶음은
/// 칸 옆의 `만들기` 를 눌러야 줄로 올라왔는데, 판에서 까맣게 칠해진 것은 `저장` 하나라
/// 이름을 친 사람은 그것을 누른다. 그러면 친 이름은 버려지고 낱말은 점이 있던 자리 —
/// 묶음이 없는 사람에게는 "나중에 정하기" — 로 조용히 갔다. 처음 담는 사람이 반드시
/// 지나가는 길이었다.
///
/// **나중에 한 쪽이 이긴다.** 이름을 친 뒤에 줄을 고르면 친 글자를 비우고, 줄을 고른
/// 뒤에 이름을 치면 친 이름으로 담는다. 무엇이 나중이었는지를 따로 적지 않아도
/// 칸이 비었는지만 보면 된다.
public struct FolderChoice: Equatable, Sendable {

    /// 점이 찍힌 줄. **`nil` 과 "안 고름"이 다르므로** 옵셔널을 겹쳐 쓰지 않고
    /// 갈래로 적는다 — `later` 는 "나중에 정하기"라는 **고른 값**이다.
    public enum Pick: Equatable, Sendable {
        case folder(String)
        case later

        public var name: String? { if case .folder(let n) = self { n } else { nil } }
    }

    public private(set) var picked: Pick
    /// 새 묶음 이름 칸에 친 글자.
    public var typed = ""

    /// 지난번에 넣은 곳이 골라진 채로 연다. 없으면 "나중에 정하기"다.
    public init(lastFolder: String?) {
        picked = lastFolder.map(Pick.folder) ?? .later
    }

    /// 줄을 고른다. 칸에 치다 만 이름은 비운다 — 줄을 고른 것이 나중의 뜻이다.
    public mutating func choose(_ pick: Pick) {
        picked = pick
        typed = ""
    }

    /// 친 이름을 줄로 올려 고른다. 빈칸뿐이면 아무 일도 없고 `false` 를 돌려준다.
    @discardableResult
    public mutating func create() -> Bool {
        guard let name = typedName else { return false }
        choose(.folder(name))
        return true
    }

    /// `저장` 을 누르면 담길 곳. `nil` 은 아무 묶음에도 넣지 않는다는 뜻이다.
    public var destination: String? { typedName ?? picked.name }

    private var typedName: String? {
        let name = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }
}
