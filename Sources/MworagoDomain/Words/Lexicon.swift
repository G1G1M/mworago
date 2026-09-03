import Foundation

/// 검색에 드는 재료 한 벌 — 사전 색인과 빈도표.
///
/// **둘을 한 벌로 묶는 것은 함께 살고 함께 죽기 때문이다.** 사전이 없으면 검색이
/// 아예 성립하지 않고, 빈도가 없으면 검색은 되지만 순위가 신문 기준으로 밀린다.
/// 그 둘의 온도차를 한 자리에 적어 두지 않으면 부르는 쪽마다 다르게 처리한다.
public struct Lexicon: Sendable {

    /// 읽기로 표제항을 찾는 자리. 파일 색인일 수도, 메모리 색인일 수도 있다.
    public let dictionary: any DictionaryLookup
    /// 도메인 빈도. **없어도 검색은 돌아간다** — 순위만 신문 기준으로 밀린다.
    public let frequency: FrequencyList?

    /// 앱에 실리는 자원의 이름. 굽는 쪽(`Tools`)과 싣는 쪽이 같은 이름을 봐야 한다.
    public static let dictionaryResource = (name: "mworago-dict", ext: "db")
    public static let frequencyResource = (name: "jesc_freq", ext: "tsv")

    public init(dictionary: any DictionaryLookup, frequency: FrequencyList?) {
        self.dictionary = dictionary
        self.frequency = frequency
    }

    public enum LoadError: Error, CustomStringConvertible {
        case missing(String)
        public var description: String {
            switch self {
            case .missing(let name): "번들에 \(name) 이 없다"
            }
        }
    }
}
