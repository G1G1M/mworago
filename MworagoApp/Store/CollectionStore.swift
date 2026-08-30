import Foundation
import Observation
import MworagoCore

/// 모은 낱말을 화면에 이어 준다.
///
/// 저장 자체는 `WordCollection`(코어)이 하고, 이쪽은 그것을 화면이 지켜볼 수 있게 감싼다.
@Observable
@MainActor
final class CollectionStore {

    private(set) var collection: WordCollection

    var words: [CollectedWord] { collection.words }

    /// 경로를 받는다. 기본값은 앱의 자리이고, 테스트는 다른 곳을 준다 —
    /// 테스트가 사용자의 진짜 파일을 건드리면 안 된다.
    init(path: String = CollectionStore.defaultPath()) {
        collection = WordCollection(path: path)
    }

    func toggle(_ word: CollectedWord) {
        if collection.contains(word) { collection.remove(word) } else { collection.add(word) }
    }

    func contains(_ word: CollectedWord) -> Bool { collection.contains(word) }

    func remove(_ word: CollectedWord) { collection.remove(word) }

    /// Application Support 아래. Documents 가 아닌 것은 사용자가 파일 앱에서 볼 것이 아니어서다.
    static func defaultPath() -> String {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("collected-words.json").path
    }
}
