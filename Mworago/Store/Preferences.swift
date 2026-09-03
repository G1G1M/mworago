import Foundation

/// 앱이 제 자료를 두는 자리.
///
/// **같은 여섯 줄이 세 곳에 복붙되어 있었다** — 모은 낱말·모습 설정·온보딩 표시가
/// 각자 Application Support 를 찾아 디렉터리를 만들고 있었다. 자리를 아는 타입을
/// 하나로 좁히면, 시험이 다른 자리를 주는 일도 한 자리에서 끝난다.
public struct AppDataDirectory: Sendable {

    public let base: URL

    /// `Documents` 가 아닌 것은 사용자가 파일 앱에서 볼 것이 아니어서다.
    public static let applicationSupport = AppDataDirectory(
        base: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory()))

    public init(base: URL) {
        self.base = base
    }

    /// 이름 하나가 놓일 자리. 부르는 김에 자리를 마련해 둔다 —
    /// 처음 켠 기기에는 이 디렉터리가 아직 없다.
    public func path(for name: String) -> String {
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent(name).path
    }
}

/// 작은 값 하나를 이름으로 적어 두고 다시 읽는 자리.
///
/// **`UserDefaults` 를 쓰지 않는다.** 그것은 사유를 밝혀야 하는 API 라, 쓰는 순간
/// 개인정보 보고서(`PrivacyInfo.xcprivacy`)에 사유를 적어야 한다. 아무것도 모으지
/// 않는다는 선언이 값 하나 때문에 길어질 이유가 없다.
///
/// 프로토콜로 두는 것은 **화면이 파일을 몰라도 되게** 하기 위해서다. 예전에는
/// 모습 설정과 온보딩 표시가 각자 뷰 파일 안에서 `FileManager` 를 불렀다.
public protocol PreferenceStoring: Sendable {
    func string(forKey key: String) -> String?
    func set(_ value: String?, forKey key: String)
    /// 값이 아니라 **있었는지**만 묻는 것. 온보딩을 봤는지 같은 것이 그렇다.
    ///
    /// 값 읽기와 따로 두는 까닭은 **적힌 것이 없어도 표시일 수 있기** 때문이다.
    /// 온보딩 표시는 빈 파일로 남겨 왔다 — 값으로 읽으면 그것이 "없음"이 되어
    /// 이미 본 사람에게 온보딩이 다시 뜬다.
    func isMarked(_ key: String) -> Bool
}

public extension PreferenceStoring {
    func isMarked(_ key: String) -> Bool { string(forKey: key) != nil }
    func mark(_ key: String) { set("1", forKey: key) }
    func unmark(_ key: String) { set(nil, forKey: key) }
}

/// 값 하나에 파일 하나.
///
/// 값이 몇 개 안 되고 서로 관계가 없어서 한 파일에 모을 이유가 없다. 손으로 열어 봤을 때
/// 무엇이 적혀 있는지 그대로 읽히는 편이 낫고, 하나가 망가져도 나머지가 멀쩡하다.
public struct FilePreferences: PreferenceStoring {

    private let directory: AppDataDirectory

    public init(in directory: AppDataDirectory = .applicationSupport) {
        self.directory = directory
    }

    /// 못 읽으면 없는 셈 친다. 손으로 고친 파일이 끝에 줄바꿈을 남길 수 있으므로 털어서 본다.
    public func string(forKey key: String) -> String? {
        guard let raw = try? String(contentsOfFile: directory.path(for: key), encoding: .utf8)
        else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public func set(_ value: String?, forKey key: String) {
        let path = directory.path(for: key)
        guard let value else {
            try? FileManager.default.removeItem(atPath: path)
            return
        }
        try? value.write(toFile: path, atomically: true, encoding: .utf8)
    }

    /// **파일이 있으면 표시다.** 안이 비어 있어도 그렇다 — 온보딩 표시를 빈 파일로
    /// 남겨 온 시절의 파일이 그대로 읽혀야 한다. 값으로 판단하면 이미 본 사람에게
    /// 온보딩이 다시 뜬다.
    public func isMarked(_ key: String) -> Bool {
        FileManager.default.fileExists(atPath: directory.path(for: key))
    }
}

/// 아무것도 남기지 않는 판. 시험과 미리보기가 쓴다.
public final class InMemoryPreferences: PreferenceStoring, @unchecked Sendable {

    private var values: [String: String] = [:]
    private let lock = NSLock()

    public init(_ values: [String: String] = [:]) {
        self.values = values
    }

    public func string(forKey key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return values[key]
    }

    public func set(_ value: String?, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        values[key] = value
    }
}
