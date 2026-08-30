import Foundation
import MworagoCore

// M0 스파이크 측정기.
// 케이스를 돌려 두 가지를 잰다.
//   1) 재현율  — 정답 가나가 후보 안에 들어는 있는가 (규칙의 한계)
//   2) 정확도  — 사전으로 거른 뒤 정답이 1위/3위 안에 오는가 (사전만으로 되는가)

struct Case {
    let hangul: String
    let reading: String
    let writing: String
    let tags: String
    let baseForm: String   // 활용형이면 사전에 실린 표기. 비면 writing과 같다
}

func loadCases(_ path: String) -> [Case] {
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
        FileHandle.standardError.write(Data("케이스 파일을 못 읽음: \(path)\n".utf8))
        exit(1)
    }
    return text.split(separator: "\n").compactMap { line in
        guard !line.hasPrefix("#") else { return nil }
        let columns = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard columns.count >= 3 else { return nil }
        return Case(hangul: columns[0], reading: columns[1], writing: columns[2],
                    tags: columns.count > 3 ? columns[3] : "",
                    baseForm: columns.count > 4 ? columns[4] : columns[2])
    }
}

/// 후보 가나들을 사전에 두드려, 살아남은 표제항을 흔한 순으로 줄 세운다.
/// 활용형은 사전에 없으므로 되돌린 형태로도 두드려 본다.
struct Hit {
    let kana: String            // 규칙이 만든 가나 후보
    let deinflection: String?   // 어떤 활용을 되돌렸나
    let entry: DictEntry
}

func search(_ hangul: String, in index: DictIndex) -> [Hit] {
    var hits: [(hit: Hit, order: Int, direct: Bool)] = []
    for (order, kana) in Transliterator.kanaCandidates(for: hangul).enumerated() {
        for deinflection in Deinflector.candidates(for: kana) {
            for entry in index.lookup(deinflection.form) {
                hits.append((Hit(kana: kana, deinflection: deinflection.rule, entry: entry),
                             order, deinflection.rule == nil))
            }
        }
    }
    // 사전에 그대로 실린 형태가 먼저, 그다음 빈도, 마지막으로 규칙이 낸 순서
    hits.sort {
        if $0.direct != $1.direct { return $0.direct }
        if $0.hit.entry.priority != $1.hit.entry.priority { return $0.hit.entry.priority > $1.hit.entry.priority }
        return $0.order < $1.order
    }
    return hits.map(\.hit)
}

/// 정답 읽기를 역변환한 형태들. 사전이 `やめろ` 대신 `やめる`를 돌려줘도 맞은 것으로 친다.
func acceptedReadings(_ reading: String) -> Set<String> {
    Set(Deinflector.candidates(for: reading).map(\.form))
}

let casesPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Data/spike-cases.tsv"
let dictPath = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "Data/JMdict_e"
let cases = loadCases(casesPath)

print("사전 읽는 중… \(dictPath)")
let loadStart = Date()
guard let dictData = FileManager.default.contents(atPath: dictPath) else {
    FileHandle.standardError.write(Data("사전 파일 없음. Scripts/fetch-jmdict.sh 를 먼저 실행\n".utf8))
    exit(1)
}
let index = DictIndex(entries: try JMDictParser.parse(data: dictData))
print("표제항 \(index.entryCount)개 · 읽기 \(index.readingCount)종 · \(String(format: "%.1f", -loadStart.timeIntervalSinceNow))초\n")

var recall = 0, strict = 0, practical = 0, top3 = 0, notFound = 0
var failures: [(Case, [Hit])] = []
var failedTags: [String: Int] = [:]
var queryTime = 0.0

print("입력          정답            살아남음  1위결과                판정")
print(String(repeating: "─", count: 72))

for testCase in cases {
    let candidates = Transliterator.kanaCandidates(for: testCase.hangul)
    if candidates.contains(testCase.reading) { recall += 1 }

    let start = Date()
    let results = search(testCase.hangul, in: index)
    queryTime += -start.timeIntervalSinceNow

    let accepted = acceptedReadings(testCase.reading)
    // 무엇으로 맞았다고 볼지는 정답의 생김새가 정한다.
    //   ① 활용형이라 사전형을 따로 적어 뒀으면 → 그 표기로 (辞める가 止める 자리를 뺏는 걸 잡는다)
    //   ② 정답에 한자가 있으면 → 표기로 (遺体가 痛い 자리를 뺏는 걸 잡는다)
    //   ③ 가나로만 쓰는 낱말이면 → 읽기로 (ありがとう의 사전 표제어는 有難う다)
    func matches(_ hit: Hit) -> Bool {
        if testCase.baseForm != testCase.writing {
            return hit.entry.writings.contains(testCase.baseForm)
        }
        if testCase.writing.contains(where: \.isKanji) {
            return hit.entry.writings.contains(testCase.writing)
        }
        return hit.entry.readings.contains { accepted.contains($0) }
    }

    let strictHit = results.first.map { $0.entry.writings.contains(testCase.writing) || ($0.entry.writings.isEmpty && $0.entry.readings.contains(testCase.reading)) } ?? false
    let practicalHit = results.first.map(matches) ?? false
    let inTop3 = results.prefix(3).contains(where: matches)

    if strictHit { strict += 1 }
    if practicalHit { practical += 1 }
    if inTop3 { top3 += 1 }
    if results.isEmpty { notFound += 1 }

    let verdict: String
    if practicalHit { verdict = strictHit ? "○" : "○ 활용복원" }
    else if inTop3 { verdict = "△ 3위안" }
    else if results.isEmpty { verdict = "✗ 사전없음" }
    else { verdict = "✗ 빗나감" }

    if !practicalHit {
        failures.append((testCase, results))
        for tag in testCase.tags.split(separator: ",") { failedTags[String(tag), default: 0] += 1 }
    }

    let top = results.first.map { hit in
        "\(hit.entry.headword)(\(hit.entry.readings.first ?? ""))" + (hit.deinflection.map { " ·\($0)" } ?? "")
    } ?? "—"
    print("\(testCase.hangul.padded(12))\(testCase.reading.padded(14))\(String(results.count).leftPadded(6))  \(top.padded(22))\(verdict)")
}

let total = cases.count
func pct(_ n: Int) -> String { "\(n)/\(total) (\(Int(Double(n) / Double(total) * 100))%)" }

print(String(repeating: "─", count: 72))
print("재현율(후보에 정답 있음)   \(pct(recall))")
print("정확도 (표기 일치, 활용 복원 인정) \(pct(practical))   ← M0 판정 기준")
print("엄격 (활용 복원 없이 표기 일치) \(pct(strict))")
print("3위 안                      \(pct(top3))")
print("사전에 아예 없음            \(pct(notFound))")
print("쿼리 평균                   \(String(format: "%.2f", queryTime / Double(total) * 1000))ms")

if !failures.isEmpty {
    print("\n놓친 케이스")
    for (testCase, results) in failures {
        let top = results.prefix(3).map { hit in
            "\(hit.entry.headword)(\(hit.entry.readings.first ?? ""))" + (hit.deinflection.map { "·\($0)" } ?? "")
        }.joined(separator: ", ")
        print("  \(testCase.hangul) → \(testCase.writing)(\(testCase.reading))  [\(testCase.tags)]")
        print("      나온 것: \(top.isEmpty ? "없음" : top)")
    }
    print("\n실패가 몰린 태그")
    for (tag, count) in failedTags.sorted(by: { $0.value > $1.value }) { print("  \(tag): \(count)건") }
}

extension Character {
    /// CJK 통합 한자 영역. 가나로만 쓰는 낱말과 한자어를 가르는 데 쓴다.
    var isKanji: Bool {
        unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }
    }
}

extension String {
    func padded(_ width: Int) -> String {
        let display = reduce(0) { $0 + ($1.isASCII ? 1 : 2) }
        return self + String(repeating: " ", count: max(0, width - display))
    }
    func leftPadded(_ width: Int) -> String {
        String(repeating: " ", count: max(0, width - count)) + self
    }
}
