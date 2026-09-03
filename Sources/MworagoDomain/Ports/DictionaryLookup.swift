import Foundation

/// 읽기로 표제항을 찾을 수 있는 것. 메모리 색인과 파일 색인이 같은 자리에 들어간다.
///
/// **`Sendable` 이어야 한다.** 찾는 일은 화면 밖에서 도는데(`Task.detached`)
/// 색인은 그 경계를 건너간다. 지금 들어가 있는 둘은 이미 만족한다 —
/// 메모리 색인은 값이고, 파일 색인은 자물쇠로 스스로를 지킨다.
public protocol DictionaryLookup: Sendable {
    func lookup(_ reading: String) -> [DictHit]
}

extension DictIndex: DictionaryLookup {}
