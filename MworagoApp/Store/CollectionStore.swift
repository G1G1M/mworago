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

    /// 묶음으로 나눈 것. **담긴 것이 없는 묶음도 자리를 지킨다** —
    /// 낱말에서만 거두면 마지막 낱말을 옮기는 순간 묶음이 사라진다.
    var folders: [CollectedWord.Folder] {
        CollectedWord.byFolder(collection.words, names: collection.folderNames)
    }

    /// 묶음만 만든다. 담기 모달의 "만들어 담기"와 다른 일이다 —
    /// 다음 화를 보기 전에 책장에 자리를 마련해 두는 길이다.
    func createFolder(_ name: String) { collection.createFolder(name) }

    /// 묶음을 손본다. 만드는 길만 내면 오타를 낸 이름이 영영 남는다.
    func renameFolder(_ old: String, to new: String) { collection.renameFolder(old, to: new) }
    /// 이름만 없앤다. 담은 낱말은 "아직 안 넣은 것"으로 남는다.
    func removeFolder(_ name: String) { collection.removeFolder(name) }

    /// 모습 설정·온보딩 표시와 같은 자리다. 자리를 아는 일은 `AppDataDirectory` 가 맡는다 —
    /// 예전에는 같은 여섯 줄이 여기와 저 둘에 각각 복붙되어 있었다.
    static func defaultPath() -> String {
        AppDataDirectory.applicationSupport.path(for: "collected-words.json")
    }
}
