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
                    tags: columns.count > 3 ? columns[3] : "")
    }
}

/// 후보 가나들을 사전에 두드려, 살아남은 표제항을 흔한 순으로 줄 세운다.
func search(_ hangul: String, in index: DictIndex) -> [(reading: String, entry: DictEntry)] {
    var hits: [(reading: String, entry: DictEntry, order: Int)] = []
    for (order, kana) in Transliterator.kanaCandidates(for: hangul).enumerated() {
        for entry in index.lookup(kana) {
            hits.append((kana, entry, order))
        }
    }
    // 빈도가 1순위, 같으면 규칙이 먼저 낸 후보가 앞
    hits.sort { $0.entry.priority != $1.entry.priority ? $0.entry.priority > $1.entry.priority : $0.order < $1.order }
    return hits.map { ($0.reading, $0.entry) }
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

var recall = 0, top1Reading = 0, top1Writing = 0, top3 = 0, notFound = 0
var failures: [(Case, [(reading: String, entry: DictEntry)])] = []
var failedTags: [String: Int] = [:]
var queryTime = 0.0

print("입력          정답            후보  살아남음  1위결과       판정")
print(String(repeating: "─", count: 68))

for testCase in cases {
    let candidates = Transliterator.kanaCandidates(for: testCase.hangul)
    if candidates.contains(testCase.reading) { recall += 1 }

    let start = Date()
    let results = search(testCase.hangul, in: index)
    queryTime += -start.timeIntervalSinceNow

    let readingHit = results.first?.reading == testCase.reading
    let writingHit = results.first.map { $0.entry.writings.contains(testCase.writing) || $0.reading == testCase.writing } ?? false
    let inTop3 = results.prefix(3).contains { $0.reading == testCase.reading }

    if readingHit { top1Reading += 1 }
    if writingHit { top1Writing += 1 }
    if inTop3 { top3 += 1 }
    if results.isEmpty { notFound += 1 }

    let verdict: String
    if writingHit { verdict = "○" }
    else if readingHit { verdict = "◐ 표기다름" }
    else if inTop3 { verdict = "△ 3위안" }
    else if results.isEmpty { verdict = "✗ 사전없음" }
    else { verdict = "✗ 빗나감" }

    if !writingHit {
        failures.append((testCase, results))
        for tag in testCase.tags.split(separator: ",") { failedTags[String(tag), default: 0] += 1 }
    }

    let top = results.first.map { "\($0.entry.headword)(\($0.reading))" } ?? "—"
    print("\(testCase.hangul.padded(12))\(testCase.reading.padded(14))\(String(candidates.count).leftPadded(4))\(String(results.count).leftPadded(8))  \(top.padded(14))\(verdict)")
}

let total = cases.count
func pct(_ n: Int) -> String { "\(n)/\(total) (\(Int(Double(n) / Double(total) * 100))%)" }

print(String(repeating: "─", count: 68))
print("재현율(후보에 정답 있음)   \(pct(recall))")
print("1위 표기까지 일치           \(pct(top1Writing))   ← M0 판정 기준")
print("1위 읽기 일치               \(pct(top1Reading))")
print("3위 안                      \(pct(top3))")
print("사전에 아예 없음            \(pct(notFound))")
print("쿼리 평균                   \(String(format: "%.2f", queryTime / Double(total) * 1000))ms")

if !failures.isEmpty {
    print("\n놓친 케이스")
    for (testCase, results) in failures {
        let top3 = results.prefix(3).map { "\($0.entry.headword)(\($0.reading))" }.joined(separator: ", ")
        print("  \(testCase.hangul) → \(testCase.writing)(\(testCase.reading))  [\(testCase.tags)]")
        print("      나온 것: \(top3.isEmpty ? "없음" : top3)")
    }
    print("\n실패가 몰린 태그")
    for (tag, count) in failedTags.sorted(by: { $0.value > $1.value }) { print("  \(tag): \(count)건") }
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
