import Foundation
import MworagoCore
#if canImport(FoundationModels)
import FoundationModels
#endif

// 한국어 뜻을 미리 구워 둔다.
//
// JMdict 는 영일 사전이라 뜻이 영어뿐이다. 한국어 뜻을 담은 공개 사전은 사실상 없고
// (JMdict 에도 독일어 33만·네덜란드어 27만 개가 있는데 한국어는 0개다),
// 검색할 때마다 번역하면 0.1ms 짜리 검색이 수백 ms 가 된다.
//
// 그래서 자주 쓰는 낱말만 미리 번역해 둔다. 도메인 빈도 상위 N 개면 실사용의 대부분을 덮는다.
// 오래 걸리는 일이라 **중단되어도 이어서** 할 수 있게 만들었다.

struct Job {
    let writing: String     // 표기 (가나 낱말이면 읽기와 같다)
    let reading: String
    let english: [String]
}

// MARK: 대상 고르기

func loadJobs(indexPath: String, frequencyPath: String, limit: Int) throws -> [Job] {
    let store = try DictionaryStore(path: indexPath)
    let frequency = FrequencyList(contentsOfFile: frequencyPath)
    guard !frequency.isEmpty else { throw Failure("빈도 목록이 비어 있다: \(frequencyPath)") }

    var jobs: [Job] = []
    var seen = Set<String>()

    for entry in frequency.sortedEntries() {
        guard jobs.count < limit else { break }
        // 사전에 있고 영어 뜻이 달린 것만 번역할 수 있다
        guard let hit = store.lookup(entry.reading).first(where: { hit in
            hit.entry.usableWritings.contains { $0.text == entry.writing }
                || (hit.entry.usableWritings.isEmpty && entry.writing == entry.reading)
        }), !hit.entry.glosses.isEmpty else { continue }

        let key = "\(entry.writing)\t\(entry.reading)"
        guard seen.insert(key).inserted else { continue }
        jobs.append(Job(writing: entry.writing, reading: entry.reading, english: hit.entry.glosses))
    }
    return jobs
}

// MARK: 번역

#if canImport(FoundationModels)
@available(macOS 26.0, *)
@Generable
struct KoreanGloss {
    @Guide(description: "한국어 뜻. 쉼표로 나눈 낱말 하나나 둘. 설명이나 문장은 쓰지 않는다.")
    var meaning: String
}

@available(macOS 26.0, *)
func translate(_ job: Job, session: LanguageModelSession) async throws -> String {
    let prompt = """
        일본어 낱말: \(job.writing)（\(job.reading)）
        영어 뜻: \(job.english.joined(separator: ", "))

        이 낱말의 한국어 뜻을 적어라.
        """
    let response = try await session.respond(to: prompt, generating: KoreanGloss.self)
    return response.content.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
}
#endif

// MARK: 실행

struct Failure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

func log(_ message: String) { FileHandle.standardError.write(Data((message + "\n").utf8)) }

let arguments = CommandLine.arguments
func value(_ flag: String) -> String? {
    guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
    return arguments[index + 1]
}

let indexPath = value("--index") ?? "Tools/data/mworago-dict.db"
let frequencyPath = value("--freq") ?? "Tools/data/jpdb_freq.csv"
let outputPath = value("--out") ?? "Tools/data/korean-gloss.tsv"
let limit = value("--limit").flatMap(Int.init) ?? 20000

// 이미 번역한 것은 건너뛴다 — 몇 시간짜리 작업이라 중단은 예외가 아니라 일상이다.
var done: Set<String> = []
if let existing = try? String(contentsOfFile: outputPath, encoding: .utf8) {
    for line in existing.split(separator: "\n") where !line.hasPrefix("#") {
        let columns = line.split(separator: "\t", omittingEmptySubsequences: false)
        if columns.count >= 2 { done.insert("\(columns[0])\t\(columns[1])") }
    }
    log("이미 끝난 것 \(done.count)개 — 건너뛴다")
}

let jobs = try loadJobs(indexPath: indexPath, frequencyPath: frequencyPath, limit: limit)
let remaining = jobs.filter { !done.contains("\($0.writing)\t\($0.reading)") }
log("대상 \(jobs.count)개 · 남은 것 \(remaining.count)개")

guard !remaining.isEmpty else {
    log("다 끝났다.")
    exit(0)
}

#if canImport(FoundationModels)
if #available(macOS 26.0, *) {
    switch SystemLanguageModel.default.availability {
    case .available:
        break
    case .unavailable(let reason):
        log("모델을 쓸 수 없다: \(reason)")
        log("시스템 설정 → Apple Intelligence & Siri 에서 켜야 한다.")
        exit(2)
    @unknown default:
        log("모델 상태를 알 수 없다")
        exit(2)
    }

    // 파일을 열어 두고 한 건씩 덧붙인다. 도중에 멈춰도 거기까지는 남는다.
    if !FileManager.default.fileExists(atPath: outputPath) {
        try "# 표기\t읽기\t한국어뜻\n".write(toFile: outputPath, atomically: true, encoding: .utf8)
    }
    let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: outputPath))
    try handle.seekToEnd()
    defer { try? handle.close() }

    let instructions = """
        너는 일본어를 한국어로 옮기는 사전 편집자다.
        낱말의 뜻만 간결하게 적는다. 설명하지 않는다.
        가장 흔한 뜻 하나나 둘만 쉼표로 나눠 적는다.
        """
    let session = LanguageModelSession(instructions: instructions)

    let start = Date()
    var count = 0
    for job in remaining {
        do {
            let korean = try await translate(job, session: session)
            guard !korean.isEmpty else { continue }
            let line = "\(job.writing)\t\(job.reading)\t\(korean)\n"
            try handle.write(contentsOf: Data(line.utf8))
            count += 1

            if count % 50 == 0 {
                let elapsed = -start.timeIntervalSinceNow
                let rate = Double(count) / elapsed
                let left = Double(remaining.count - count) / max(rate, 0.001)
                log(String(format: "  %d/%d · %.1f건/초 · 남은 시간 %.0f분",
                           count, remaining.count, rate, left / 60))
            }
        } catch {
            log("  건너뜀 \(job.writing)(\(job.reading)): \(error)")
        }
    }
    log("번역 \(count)개 완료 → \(outputPath)")
} else {
    log("macOS 26 이상이 필요하다.")
    exit(2)
}
#else
log("이 SDK 에는 FoundationModels 가 없다.")
exit(2)
#endif
