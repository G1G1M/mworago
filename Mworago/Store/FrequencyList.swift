import Foundation

/// 도메인 말뭉치 기준 낱말 빈도.
///
/// JMdict의 빈도 태그는 **신문 말뭉치** 기준이라 애니 대사와 어긋난다.
/// 신문에서는 "유체"가 "아프다"보다 흔하지만, 애니에서는 정반대다.
///
/// ```
/// 遺体(いたい)  JMdict 67점 · 애니 4680위
/// 痛い(いたい)  JMdict 54점 · 애니  592위   ← 여덟 배 흔하다
/// ```
///
/// 형식은 JPDB 배포본과 같은 탭 구분 표다. `term / reading / frequency`,
/// frequency는 **순위**여서 작을수록 흔하다.
public struct FrequencyList: Sendable {

    struct Key: Hashable {
        let writing: String
        let reading: String
    }

    private let ranks: [Key: Int]

    public var isEmpty: Bool { ranks.isEmpty }
    public var count: Int { ranks.count }

    public init(tsv: String) {
        var ranks: [Key: Int] = [:]
        for line in tsv.split(separator: "\n").dropFirst() {   // 첫 줄은 헤더
            let columns = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard columns.count >= 3, let rank = Int(columns[2]) else { continue }
            let key = Key(writing: String(columns[0]), reading: String(columns[1]))
            // 같은 낱말이 여러 번 나오면 더 흔한(순위가 앞선) 쪽을 남긴다
            if let existing = ranks[key], existing <= rank { continue }
            ranks[key] = rank
        }
        self.ranks = ranks
    }

    public init(contentsOfFile path: String) {
        self.init(tsv: (try? String(contentsOfFile: path, encoding: .utf8)) ?? "")
    }

    /// 순위가 앞선 것부터 (순위, 표기, 읽기). 케이스를 뽑을 때 쓴다.
    public func sortedEntries() -> [(rank: Int, writing: String, reading: String)] {
        ranks.map { (rank: $0.value, writing: $0.key.writing, reading: $0.key.reading) }
            .sorted { $0.rank < $1.rank }
    }

    /// 이 낱말의 순위. 표기를 주지 않으면 가나로만 쓰는 낱말로 보고 찾는다.
    public func rank(writing: String?, reading: String) -> Int? {
        ranks[Key(writing: writing ?? reading, reading: reading)]
    }

    /// 순위를 점수로. 순위는 로그 스케일로 벌어지므로 그대로 쓰면 상위권이 뭉친다.
    ///
    /// 1위 120점 · 200위 74점 · 600위 65점 · 5000위 46점 · 10000위 40점.
    /// 목록에 없으면 0점 — 감점이 아니라 "이 층이 아무 말도 하지 않음"이다.
    public func score(writing: String?, reading: String) -> Double {
        guard let rank = rank(writing: writing, reading: reading), rank > 0 else { return 0 }
        return max(0, 120 - 20 * log10(Double(rank)))
    }
}
