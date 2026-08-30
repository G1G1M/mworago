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

    public struct Key: Hashable, Sendable {
        public let writing: String
        public let reading: String
        public init(writing: String, reading: String) {
            self.writing = writing
            self.reading = reading
        }
    }

    private let ranks: [Key: Int]
    /// 표기만으로 찾을 때 쓸 최고 순위(가장 흔한 읽기의 것).
    private let ranksByWriting: [String: Int]

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

        var byWriting: [String: Int] = [:]
        for (key, rank) in ranks {
            if let existing = byWriting[key.writing], existing <= rank { continue }
            byWriting[key.writing] = rank
        }

        self.ranks = ranks
        self.ranksByWriting = byWriting
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
    /// 표기와 읽기가 **둘 다** 맞아야 한다 — `痛い`는 `つう`로 읽지 않는다.
    public func rank(writing: String?, reading: String) -> Int? {
        ranks[Key(writing: writing ?? reading, reading: reading)]
    }

    /// 읽기를 묻지 않고 표기만으로 찾은 최고 순위.
    ///
    /// 빈도를 세는 쪽이 `何`를 늘 `なん`으로만 읽어 `なに` 항목이 없는 일이 있다.
    /// 같은 표기의 다른 읽기라도 그 낱말이 흔하다는 사실은 알려 준다.
    /// **다만 그 읽기가 정말 그 낱말의 읽기인지는 이쪽에서 알 수 없다.**
    /// 사전 항목을 손에 쥔 쪽(`Ranker`)만 그 판단을 할 수 있으므로, 거기서만 써야 한다.
    public func rankByWriting(_ writing: String) -> Int? {
        ranksByWriting[writing]
    }

    public func scoreByWriting(_ writing: String) -> Double {
        guard let rank = rankByWriting(writing), rank > 0 else { return 0 }
        return max(0, 120 - 20 * log10(Double(rank)))
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
