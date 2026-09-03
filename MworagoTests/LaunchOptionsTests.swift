import Testing
import Foundation
@testable import MworagoDomain

@Suite("실행 인자")
struct LaunchOptionsTests {

    @Test("붙어 있는 표시를 알아본다")
    func 표시() {
        let options = LaunchOptions(["앱", "--guide", "--no-splash"])
        #expect(options.has("guide"))
        #expect(options.has("no-splash"))
        #expect(!options.has("quiz"))
    }

    @Test("이름 뒤에 붙은 값을 꺼낸다")
    func 값() {
        let options = LaunchOptions(["앱", "--query=다이죠부데스카", "--select=1"])
        #expect(options.value(for: "query") == "다이죠부데스카")
        #expect(options.int(for: "select") == 1)
    }

    @Test("값이 붙은 것은 표시가 아니다")
    func 값과표시를가른다() {
        // `--detail` 과 `--detail=あ` 는 다른 뜻으로 쓰이고 있다 —
        // 책장은 첫 낱말을 펼치고, 글자 화면은 그 글자를 펼친다.
        let options = LaunchOptions(["앱", "--detail=あ"])
        #expect(!options.has("detail"))
        #expect(options.value(for: "detail") == "あ")

        let bare = LaunchOptions(["앱", "--detail"])
        #expect(bare.has("detail"))
        #expect(bare.value(for: "detail") == nil)
    }

    @Test("이름만 있고 값이 비면 빈 문자열")
    func 빈값() {
        // `--folder=` 처럼 이름을 안 적은 것은 "첫 묶음"을 뜻한다. nil 과 갈라야 한다.
        let options = LaunchOptions(["앱", "--folder="])
        #expect(options.value(for: "folder") == "")
        #expect(!options.has("folder"))
    }

    @Test("숫자가 아니면 nil")
    func 숫자아님() {
        let options = LaunchOptions(["앱", "--select=하나"])
        #expect(options.int(for: "select") == nil)
        #expect(options.value(for: "select") == "하나")
    }

    @Test("없는 것을 물으면 조용히 없다고 한다")
    func 없는것() {
        let options = LaunchOptions(["앱"])
        #expect(!options.has("guide"))
        #expect(options.value(for: "query") == nil)
        #expect(options.int(for: "select") == nil)
    }

    @Test("같은 이름이 여럿이면 앞선 것을 쓴다")
    func 중복() {
        let options = LaunchOptions(["앱", "--query=먼저", "--query=나중"])
        #expect(options.value(for: "query") == "먼저")
    }

    @Test("이름이 겹쳐 시작해도 헷갈리지 않는다")
    func 접두어() {
        // `--list-picking` 이 있다고 `--picking` 이 켜지면 안 된다 —
        // 책장의 목록 고르기와 묶음 화면의 고르기는 한 화면에 겹쳐 설 수 있다.
        let options = LaunchOptions(["앱", "--list-picking"])
        #expect(options.has("list-picking"))
        #expect(!options.has("picking"))

        let valued = LaunchOptions(["앱", "--onboarding-page=2"])
        #expect(valued.int(for: "onboarding-page") == 2)
        #expect(valued.value(for: "onboarding") == nil)
        #expect(!valued.has("onboarding"))
    }

    @Test("아무 인자도 없는 것이 기본이다")
    func 빈것() {
        #expect(!LaunchOptions.none.has("guide"))
        #expect(LaunchOptions.none.value(for: "query") == nil)
    }
}
