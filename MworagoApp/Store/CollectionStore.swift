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

    /// 담는다. 어디에 넣을지 함께 받는다 — 담기 모달이 물어서 가져온다.
    func add(_ word: CollectedWord, to folder: String?) { collection.add(word, to: folder) }

    func contains(_ word: CollectedWord) -> Bool { collection.contains(word) }

    func remove(_ word: CollectedWord) { collection.remove(word) }

    /// 지난번에 넣은 곳. 담기 모달이 이것을 미리 골라 둔다.
    var lastFolder: String? { collection.lastFolder }
    var folderNames: [String] { collection.folderNames }
    func move(_ word: CollectedWord, to folder: String?) { collection.move(word, to: folder) }

    /// 묶음을 손본다. 만드는 길만 내면 오타를 낸 이름이 영영 남는다.
    func renameFolder(_ old: String, to new: String) { collection.renameFolder(old, to: new) }
    /// 이름만 없앤다. 담은 낱말은 "아직 안 넣은 것"으로 남는다.
    func removeFolder(_ name: String) { collection.removeFolder(name) }

    /// Application Support 아래. Documents 가 아닌 것은 사용자가 파일 앱에서 볼 것이 아니어서다.
    static func defaultPath() -> String {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("collected-words.json").path
    }
}
