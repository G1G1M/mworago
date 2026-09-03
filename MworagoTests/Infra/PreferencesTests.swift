import Testing
import Foundation
@testable import MworagoDomain
@testable import MworagoInfra

@Suite("작은 값 적어 두기")
struct PreferencesTests {

    /// 시험마다 제 자리를 쓴다. **사용자의 진짜 파일을 건드리면 안 된다** —
    /// 모은 낱말과 같은 자리에 놓이는 것들이라 더 그렇다.
    static func 임시자리() -> AppDataDirectory {
        AppDataDirectory(base: URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("mworago-prefs-\(UUID().uuidString)"))
    }

    @Test("적어 두면 다시 읽힌다")
    func 왕복() throws {
        let directory = Self.임시자리()
        defer { try? FileManager.default.removeItem(at: directory.base) }

        let prefs = FilePreferences(in: directory)
        prefs.set("dark", forKey: "appearance")

        // 새로 세운 것이 읽어야 한다. 들고 있던 값이 아니라 파일에서 온 것이어야 하므로.
        #expect(FilePreferences(in: directory).string(forKey: "appearance") == "dark")
    }

    @Test("적은 적 없는 것은 nil")
    func 없는키() {
        let directory = Self.임시자리()
        defer { try? FileManager.default.removeItem(at: directory.base) }

        #expect(FilePreferences(in: directory).string(forKey: "appearance") == nil)
    }

    @Test("nil 을 넣으면 지워진다")
    func 지우기() {
        let directory = Self.임시자리()
        defer { try? FileManager.default.removeItem(at: directory.base) }

        let prefs = FilePreferences(in: directory)
        prefs.set("light", forKey: "appearance")
        prefs.set(nil, forKey: "appearance")

        #expect(prefs.string(forKey: "appearance") == nil)
    }

    @Test("앞뒤 공백은 털어서 읽는다")
    func 공백() throws {
        let directory = Self.임시자리()
        defer { try? FileManager.default.removeItem(at: directory.base) }

        // 손으로 고친 파일이 끝에 줄바꿈을 남길 수 있다. 그 한 글자에 설정이 날아가면 안 된다.
        try "dark\n".write(toFile: directory.path(for: "appearance"),
                           atomically: true, encoding: .utf8)

        #expect(FilePreferences(in: directory).string(forKey: "appearance") == "dark")
    }

    @Test("자리는 없으면 만들어진다")
    func 자리만들기() {
        let directory = Self.임시자리()
        defer { try? FileManager.default.removeItem(at: directory.base) }

        // 처음 켠 기기에는 Application Support 아래에 아무것도 없다.
        FilePreferences(in: directory).set("system", forKey: "appearance")

        #expect(FileManager.default.fileExists(atPath: directory.path(for: "appearance")))
    }

    @Test("적어 둔 표시가 있는지 묻는다")
    func 표시() {
        let directory = Self.임시자리()
        defer { try? FileManager.default.removeItem(at: directory.base) }

        let prefs = FilePreferences(in: directory)
        #expect(!prefs.isMarked("onboarding-seen"))
        prefs.mark("onboarding-seen")
        #expect(prefs.isMarked("onboarding-seen"))
    }

    @Test("예전에 남긴 빈 표시 파일도 본 것으로 친다")
    func 빈표시파일() throws {
        let directory = Self.임시자리()
        defer { try? FileManager.default.removeItem(at: directory.base) }

        // 온보딩 표시는 오래도록 **빈 파일**이었다. 값으로 읽으면 "없음"이 되어
        // 이미 본 사람에게 온보딩이 다시 뜬다 — 그 회귀를 여기서 못 박는다.
        FileManager.default.createFile(atPath: directory.path(for: "onboarding-seen"),
                                       contents: nil)

        let prefs = FilePreferences(in: directory)
        #expect(prefs.isMarked("onboarding-seen"))
        #expect(prefs.string(forKey: "onboarding-seen") == nil)
    }

    @Test("표시를 지우면 없어진다")
    func 표시지우기() {
        let directory = Self.임시자리()
        defer { try? FileManager.default.removeItem(at: directory.base) }

        let prefs = FilePreferences(in: directory)
        prefs.mark("onboarding-seen")
        prefs.unmark("onboarding-seen")

        #expect(!prefs.isMarked("onboarding-seen"))
    }

    @Test("메모리 판은 파일을 만들지 않는다")
    func 메모리판() {
        // 시험과 미리보기가 쓰는 것. 자리를 치울 일도, 남길 일도 없다.
        let prefs = InMemoryPreferences()
        prefs.set("light", forKey: "appearance")

        #expect(prefs.string(forKey: "appearance") == "light")
        #expect(!prefs.isMarked("onboarding-seen"))
    }
}
