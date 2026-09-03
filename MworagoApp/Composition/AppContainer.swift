import Foundation
import MworagoCore

/// 앱이 쓰는 것들을 한자리에서 세운다.
///
/// **조립을 화면이 나눠 하고 있었다.** 뿌리 화면이 모은 낱말을 만들고, 찾기 화면이
/// 검색기와 옮긴 말을 만들었다 — 무엇이 언제 서는지가 화면 계층에 흩어져 있었고,
/// 화면을 세우지 않고는 그 조립을 한 번도 밟을 수 없었다.
///
/// 여기서 한 번 세우고 `MworagoApp` 이 화면으로 내려보낸다. 미리보기와 화면 확인은
/// 필요한 것만 갈아끼운다 — 아무것도 남기지 않는 설정, 임시 자리의 사전.
@MainActor
struct AppContainer {

    /// 작은 값을 적어 두는 자리. **화면에 `@Environment` 로 내려가지 않는다** —
    /// 뿌리 화면이 첫 모습을 정할 때 `init` 안에서 읽어야 하는데, 그 자리에서는
    /// 환경을 아직 볼 수 없다. 그래서 이것만 생성자로 건넨다.
    let preferences: any PreferenceStoring
    /// 모은 낱말. 찾기 · 책장 · 연습이 같은 것을 본다.
    let collection: CollectionStore
    /// 사전을 열고 검색을 맡는다.
    let engine: SearchEngine
    /// 옮긴 말을 모아 두는 곳.
    let desk: TranslationDesk

    init(preferences: any PreferenceStoring = FilePreferences(),
         collection: CollectionStore = CollectionStore(),
         engine: SearchEngine = SearchEngine(),
         desk: TranslationDesk = TranslationDesk()) {
        self.preferences = preferences
        self.collection = collection
        self.engine = engine
        self.desk = desk
    }
}
