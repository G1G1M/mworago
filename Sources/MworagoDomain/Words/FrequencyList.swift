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
    /// 말뭉치에 몇 번 나왔는가. **순위로는 못 하는 물음이 하나 있다** —
    /// "이 낱말을 사람들이 한자로 적는가, 가나로 적는가". 그것은 두 표기의 **횟수 비**라서
    /// 순위 차로는 가늠이 안 된다(`丘` 314 대 `おか` 357 은 순위로 멀어 보인다).
    private let occurrences: [Key: Int]
    /// 조회 키로 접기 **전**의 읽기 글자. 키는 장음을 하나로 접지만
    /// (`おおきい` → `おーきー`), 밖으로 내보낼 때는 사전이 든 글자 그대로여야 한다.
    private let readingTexts: [Key: String]

    public var isEmpty: Bool { ranks.isEmpty }
    public var count: Int { ranks.count }

    public init(tsv: String) {
        var ranks: [Key: Int] = [:]
        var occurrences: [Key: Int] = [:]
        var readingTexts: [Key: String] = [:]
        for line in tsv.split(separator: "\n").dropFirst() {   // 첫 줄은 헤더
            let columns = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard columns.count >= 3, let rank = Int(columns[2]) else { continue }
            let key = Key(writing: String(columns[0]),
                          reading: KanaTable.lookupKey(String(columns[1])))
            if columns.count >= 4, let count = Int(columns[3]) {
                occurrences[key] = max(occurrences[key] ?? 0, count)
            }
            // 같은 낱말이 여러 번 나오면 더 흔한(순위가 앞선) 쪽을 남긴다
            if let existing = ranks[key], existing <= rank { continue }
            ranks[key] = rank
            readingTexts[key] = String(columns[1])
        }

        var byWriting: [String: Int] = [:]
        for (key, rank) in ranks {
            if let existing = byWriting[key.writing], existing <= rank { continue }
            byWriting[key.writing] = rank
        }

        self.ranks = ranks
        self.ranksByWriting = byWriting
        self.occurrences = occurrences
        self.readingTexts = readingTexts
    }

    /// **이 낱말을 말뭉치가 한자로 적는 비율.** 0 이면 늘 가나로 적는다는 뜻이다.
    ///
    /// 사전의 `uk`(보통 가나로 씀) 태그는 갈래가 너무 넓다. `丘`(47%)·`霞`(44%)·`傘`(34%)
    /// 처럼 자막이 절반 가까이 한자로 적는 낱말과, `生る`(0%)·`貴方`(5%)·`為`(20%) 처럼
    /// 사실상 가나로만 적는 낱말이 한 통에 담겨 있다. 말뭉치는 그 둘을 가른다.
    public func kanjiShare(writing: String, reading: String) -> Double {
        let key = KanaTable.lookupKey(reading)
        let kanji = occurrences[Key(writing: writing, reading: key)] ?? 0
        let kana = occurrences[Key(writing: reading, reading: key)] ?? 0
        guard kanji + kana > 0 else { return 0 }
        return Double(kanji) / Double(kanji + kana)
    }

    /// 순위가 앞선 것부터 (순위, 표기, 읽기). 케이스를 뽑을 때 쓴다.
    ///
    /// **읽기는 접기 전 글자로 돌려준다.** 안에서 쓰는 키는 장음을 하나로 접는데
    /// (`おおきい` → `おーきー`), 그 접힌 글자를 그대로 내보내면 사전이 든 읽기와
    /// 어긋난다. 뜻을 굽는 쪽이 둘을 맞대어 대상을 고르므로(`Translator.loadJobs`)
    /// 어긋나는 순간 **장음이 든 낱말이 통째로 대상에서 빠진다** — 재 보니 빈도 목록
    /// 69,048개 중 7,653개(11%)였고, 구멍을 세는 쪽도 같은 잣대라 안 보였다.
    public func sortedEntries() -> [(rank: Int, writing: String, reading: String)] {
        ranks.map { (rank: $0.value, writing: $0.key.writing,
                     reading: readingTexts[$0.key] ?? $0.key.reading) }
            .sorted { $0.rank < $1.rank }
    }

    /// 이 낱말의 순위. 표기를 주지 않으면 가나로만 쓰는 낱말로 보고 찾는다.
    /// 표기와 읽기가 **둘 다** 맞아야 한다 — `痛い`는 `つう`로 읽지 않는다.
    public func rank(writing: String?, reading: String) -> Int? {
        // **읽기는 사전 조회와 같은 키로 맞춘다.**
        //
        // 빈도를 센 쪽은 외래어를 `ブラシ · ぶらし`(표기는 가타카나, 읽기는 히라가나)로
        // 싣는데, 사전은 그 낱말의 읽기를 `ブラシ` 로 싣는다. 글자가 어긋나 조회가
        // 빗나가면서 **가타카나 낱말 14,630 개가 통째로 0점**이었다 —
        // `コート` 는 536번 나오는데도 그랬다.
        //
        // 그 바람에 분절이 외래어를 깨뜨렸다. `に + ブラシ` 로 나누면 조각 비용을 두 번
        // 내야 하는데 ブラシ 가 0점이라 못 버티고, `にぶらし`(鈍らす·둔하게 하다)로
        // 뭉쳐 버린다. 화면에는 "옷이 둔해져서"가 나온다.
        //
        // 같은 키로 접으면 장음 표기 차이(`こおと` · `コート`)까지 함께 만난다.
        ranks[Key(writing: writing ?? reading, reading: KanaTable.lookupKey(reading))]
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
