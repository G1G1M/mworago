import Foundation
import MworagoDomain
import MworagoUseCases

/// 자원 자리를 물어 재료를 연다.
///
/// **여는 일만 여기 있다.** 재료가 무엇인지(`Lexicon`)와 자리를 어떻게 묻는지
/// (`ResourceLocating`)는 도메인이 알고, **무엇으로 여는지**(SQLite 색인 파일)는
/// 이 자리가 안다. 그래서 검색 쪽은 사전이 파일인지 메모리인지 모른 채 돈다.
public extension Lexicon {
    /// 자원 자리를 물어 재료를 연다.
    ///
    /// 무거운 일은 여기 없다. 색인은 파일이라 여는 순간 아무것도 읽지 않고,
    /// 빈도표만 한 번 훑는다.
    init(locating locator: some ResourceLocating) throws {
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
}
