import Foundation

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
