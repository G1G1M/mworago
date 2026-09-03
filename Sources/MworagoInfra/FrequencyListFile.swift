import Foundation
import MworagoDomain
import MworagoUseCases

public extension FrequencyList {
    /// 파일에서 읽는다. **표 자체는 도메인이 알고 파일은 여기가 안다** —
    /// 읽지 못하면 빈 표가 되고, 빈 표를 쓸지 말지는 부르는 쪽이 정한다.
    init(contentsOfFile path: String) {
        self.init(tsv: (try? String(contentsOfFile: path, encoding: .utf8)) ?? "")
    }
}
