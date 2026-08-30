import Foundation

/// 한자를 한국 독음으로 읽는 표.
///
/// 쓸 수 있는 한일 사전이 없어 뜻은 영어로 남아 있다. 그 사이를 메우는 단서다.
/// 한국어 화자는 한자어 어휘를 이미 갖고 있어서, 독음만 보여도 절반은 통한다.
///
/// ```
/// 約束(やくそく) → 약속      뜻까지 그대로 통한다
/// 大丈夫(だいじょうぶ) → 대장부   독음은 알겠는데 뜻은 다르다 (괜찮다)
/// ```
///
/// **뜻이 아니라 단서다.** 한자어의 절반쯤은 한국어와 의미가 통하고 절반은 다르므로,
/// 뜻 자리에 놓지 않고 한자 곁에 둔다.
public struct HanjaReading: Sendable {

    private let table: [Character: String]

    public var isEmpty: Bool { table.isEmpty }
    public var count: Int { table.count }

    public init(tsv: String) {
        var table: [Character: String] = [:]
        for line in tsv.split(separator: "\n") where !line.hasPrefix("#") {
            let columns = line.split(separator: "\t")
            guard columns.count >= 2, let hanja = columns[0].first else { continue }
            table[hanja] = String(columns[1])
        }
        self.table = table
    }

    public init(contentsOfFile path: String) {
        self.init(tsv: (try? String(contentsOfFile: path, encoding: .utf8)) ?? "")
    }

    /// 표기에 든 한자를 이어 읽는다. 한자가 하나도 없으면 nil.
    ///
    /// 가나는 건너뛴다 — `痛い`는 "통"이다. 한 글자만 남더라도 "통증"의 그 통이라는 단서가 된다.
    public func reading(of writing: String) -> String? {
        var result = ""
        for character in writing {
            guard let reading = table[character] else { continue }
            result += reading
        }
        return result.isEmpty ? nil : result
    }
}
