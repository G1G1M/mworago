import Foundation

/// 밖에서 "이 묶음을 열어 달라"고 건네는 이름.
///
/// **옵셔널 하나로는 모자란다.** 이름 없는 묶음(`아직 안 넣은 것`)이 실재하므로,
/// `String?` 만으로는 `nil` 이 "그 묶음"과 "건넨 것 없음" 둘을 뜻하게 된다.
struct FolderRoute: Equatable, Identifiable {
    let name: String?
    var id: String { name ?? "\u{1F}없음" }
    /// 화면에 적을 이름.
    var title: String { name ?? "아직 안 넣은 것" }
}
