import Foundation

/// 자원이 어디 있는지 대답하는 것.
///
/// **`Bundle.main` 을 직접 부르지 않기 위해 있다.** 예전에는 검색기가 스스로 번들을
/// 뒤져 사전 파일을 찾았는데, 그러면 그 길이 앱 안에서만 밟힌다 — 재료를 여는 일이
/// 잘못됐는지 시험할 방법이 없고, 화면을 세우지 않고는 검색기를 만들 수도 없다.
///
/// 무엇을 어디서 찾을지는 **부르는 쪽**이 정한다. 앱은 번들을 주고, 시험은 임시 자리를
/// 주고, 측정 도구는 작업 폴더를 준다.
public protocol ResourceLocating: Sendable {
    /// 없으면 `nil`. 있는지 없는지는 부르는 쪽이 판단한다.
    func path(forResource name: String, ofType ext: String) -> String?
}

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

    /// 자원 자리를 물어 재료를 연다.
    ///
    /// 무거운 일은 여기 없다. 색인은 파일이라 여는 순간 아무것도 읽지 않고,
    /// 빈도표만 한 번 훑는다.
    public init(locating locator: some ResourceLocating) throws {
        let names = Self.dictionaryResource
        guard let path = locator.path(forResource: names.name, ofType: names.ext) else {
            throw LoadError.missing("\(names.name).\(names.ext)")
        }
        let dictionary = try DictionaryStore(path: path)

        // 빈도는 없어도 검색은 돌아간다. 굽다 만 파일이 실려 비어 있을 수도 있는데,
        // 그때 빈 표를 그대로 쓰면 사전이 아는 낱말까지 전부 0점이 된다.
        var frequency: FrequencyList?
        let freqNames = Self.frequencyResource
        if let path = locator.path(forResource: freqNames.name, ofType: freqNames.ext) {
            let list = FrequencyList(contentsOfFile: path)
            frequency = list.isEmpty ? nil : list
        }

        self.init(dictionary: dictionary, frequency: frequency)
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
