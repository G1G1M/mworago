import Testing
@testable import MworagoDomain

@Suite("담기 판에서 고른 자리")
struct FolderChoiceTests {

    @Test("열면 지난번 묶음이 골라져 있고, 없으면 나중에 정하기다")
    func 처음자리() {
        #expect(FolderChoice(lastFolder: "리코리스 3화").destination == "리코리스 3화")
        #expect(FolderChoice(lastFolder: nil).destination == nil)
    }

    @Test("이름을 치고 만들기 없이 저장하면 친 이름으로 담긴다")
    func 친이름으로담는다() {
        // 묶음이 없는 사람이 처음 담을 때다. 칸에 이름을 치고 까만 `저장` 을 바로 누르면
        // 친 글자가 버려지고 "아직 안 넣은 것"으로 갔다.
        var choice = FolderChoice(lastFolder: nil)
        choice.typed = "리코리스 3화"
        #expect(choice.destination == "리코리스 3화")
    }

    @Test("지난번 묶음이 골라져 있어도 칸에 친 이름이 이긴다")
    func 친이름이지난번을이긴다() {
        var choice = FolderChoice(lastFolder: "봇치 더 록 1화")
        choice.typed = "봇치 더 록 2화"
        #expect(choice.destination == "봇치 더 록 2화")
    }

    @Test("빈칸만 친 것은 이름이 아니다")
    func 빈칸은이름이아니다() {
        var choice = FolderChoice(lastFolder: "봇치 더 록 1화")
        choice.typed = "   "
        #expect(choice.destination == "봇치 더 록 1화")
    }

    @Test("이름 앞뒤의 빈칸은 떼고 담는다")
    func 앞뒤빈칸() {
        var choice = FolderChoice(lastFolder: nil)
        choice.typed = "  리코리스 3화 "
        #expect(choice.destination == "리코리스 3화")
    }

    @Test("이름을 친 뒤 줄을 고르면 고른 줄이 이긴다")
    func 나중에고른줄이이긴다() {
        var choice = FolderChoice(lastFolder: nil)
        choice.typed = "리코"
        choice.choose(.folder("리코리스 리코일 3화"))
        #expect(choice.typed.isEmpty)
        #expect(choice.destination == "리코리스 리코일 3화")

        choice.typed = "리코"
        choice.choose(.later)
        #expect(choice.destination == nil)
    }

    @Test("만들기를 누르면 새 이름이 골라지고 칸이 빈다")
    func 만들기() {
        var choice = FolderChoice(lastFolder: "봇치 더 록 1화")
        choice.typed = " 귀멸의 칼날 "
        choice.create()
        #expect(choice.picked == .folder("귀멸의 칼날"))
        #expect(choice.typed.isEmpty)
        #expect(choice.destination == "귀멸의 칼날")
    }

    @Test("빈 칸으로 만들기를 누르면 아무것도 바뀌지 않는다")
    func 빈만들기() {
        var choice = FolderChoice(lastFolder: "봇치 더 록 1화")
        choice.typed = "  "
        choice.create()
        #expect(choice.picked == .folder("봇치 더 록 1화"))
    }
}
