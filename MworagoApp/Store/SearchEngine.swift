import Foundation
import Observation
import MworagoCore

/// 사전을 열고 검색을 맡는다.
///
/// 무거운 일은 앱을 켤 때 한 번뿐이고, 그마저도 색인 파일이라 거의 즉시 끝난다
/// (XML 을 파싱하던 시절에는 3.1초였다).
@Observable
@MainActor
final class SearchEngine {

    private(set) var segments: [Segment] = []
    private(set) var isReady = false
    private(set) var failure: String?

    private var store: DictionaryStore?
    private var frequency: FrequencyList?
    /// 한자의 한국 독음. 쓸 만한 한일 사전이 없어 뜻이 영어로 남은 사이를 메우는 단서다.

    init() {
        do {
            guard let dictPath = Bundle.main.path(forResource: "mworago-dict", ofType: "db") else {
                throw LoadError.missing("mworago-dict.db")
            }
            store = try DictionaryStore(path: dictPath)

            // 빈도는 없어도 검색은 돌아간다. 순위만 신문 기준으로 밀린다.
            if let freqPath = Bundle.main.path(forResource: "jesc_freq", ofType: "tsv") {
                let list = FrequencyList(contentsOfFile: freqPath)
                frequency = list.isEmpty ? nil : list
            }
            isReady = true
        } catch {
            failure = String(describing: error)
        }
    }

    /// 입력을 낱말로 나누고 각각을 찾는다. 띄어 쓰지 않아도 사전이 알아서 끊는다.
    func search(_ input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let store, !trimmed.isEmpty else {
            segments = []
            return
        }
        segments = Segmenter.segment(trimmed, in: store, frequency: frequency)
    }

    enum LoadError: Error, CustomStringConvertible {
        case missing(String)
        var description: String {
            switch self {
            case .missing(let name): "번들에 \(name) 이 없다"
            }
        }
    }
}
