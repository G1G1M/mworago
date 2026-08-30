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
    let wordClass: WordClass
}

// MARK: 대상 고르기

func loadJobs(indexPath: String, frequencyPath: String, limit: Int) throws -> [Job] {
    let store = try DictionaryStore(path: indexPath)
    let frequency = FrequencyList(contentsOfFile: frequencyPath)
    guard !frequency.isEmpty else { throw Failure("빈도 목록이 비어 있다: \(frequencyPath)") }

    var jobs: [Job] = []
    var seen = Set<String>()
    var skipped = 0

    for entry in frequency.sortedEntries() {
        guard jobs.count < limit else { break }
        // 사전에 있고 영어 뜻이 달린 것만 번역할 수 있다
        guard let hit = store.lookup(entry.reading).first(where: { hit in
            // **가나 종류까지 같아야 한다.** 색인 조회 키는 히라가나로 정규화돼 있어서
            // でも 로 찾으면 デモ(시위)가 함께 걸려 나오고, 표기 없는 항목끼리 비교하면
            // 그대로 통과해 버린다. 실제로 でも 의 뜻이 "demonstration, protest" 였고
            // もの 는 "mono" 였다 — 모델은 받은 대로 옮겼을 뿐이다.
            hit.reading == entry.reading
                && (hit.entry.usableWritings.contains { $0.text == entry.writing }
                    || (hit.entry.usableWritings.isEmpty && entry.writing == entry.reading))
        }), !hit.entry.glosses.isEmpty else { continue }

        // **조사·조동사·계사는 건너뛴다.** 뜻이 아니라 기능이라 낱말 뜻으로 옮길 수가 없다.
        // 사전의 영어 뜻부터가 설명문이고(`の` → "indicates possessive"),
        // 그대로 넘기면 뜻 자리에 문장이 들어앉는다(`よ` → "안녕, 너").
        // 하필 빈도 최상위가 전부 이것들이라, 안 거르면 상위 N 개가 통째로 쓰레기가 된다.
        guard hit.entry.wordClass.isTranslatable else { skipped += 1; continue }

        let key = "\(entry.writing)\t\(entry.reading)"
        guard seen.insert(key).inserted else { continue }
        jobs.append(Job(writing: entry.writing, reading: entry.reading,
                        english: hit.entry.glosses, wordClass: hit.entry.wordClass))
    }
    if skipped > 0 { log("기능어 \(skipped)개는 건너뛴다 — 조사·조동사는 뜻으로 옮길 수 없다") }
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
func translate(_ job: Job, instructions: String) async throws -> String {
    // **세션은 건마다 새로 연다.** 하나를 계속 쓰면 주고받은 것이 전부 이력으로 쌓여
    // 컨텍스트가 불어나고, 얼마 못 가 전부 `exceededContextWindowSize` 로 죽는다
    // (실제로 세 번째 낱말에서 이미 4,090/4,096 토큰이었다).
    // 낱말 하나를 옮기는 일은 앞 낱말과 아무 관계가 없으니 이력은 낭비일 뿐이다.
    let session = LanguageModelSession(instructions: instructions)
    // 품사를 알려 주지 않으면 동사가 명사로 돌아온다 — 思う(to think)가 "생각하다"가 아니라 "생각".
    // 영어 뜻만으로는 to- 부정사가 한국어 어미로 옮겨질 근거가 없다.
    let 품사 = job.wordClass.koreanName.map { "품사: \($0)\n" } ?? ""
    let prompt = """
        일본어 낱말: \(job.writing)（\(job.reading)）
        \(품사)영어 뜻: \(job.english.joined(separator: ", "))

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
// 모델에 무엇이 넘어가는지만 보고 끝낸다. 결과가 이상할 때
// 사전에서 잘못 골랐는지 모델이 잘못 옮겼는지부터 갈라야 하기 때문이다.
let dryRun = arguments.contains("--dry-run")

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

if dryRun {
    for job in jobs {
        let 품사 = job.wordClass.koreanName ?? job.wordClass.rawValue
        print("\(job.writing)\t\(job.reading)\t\(품사)\t\(job.english.joined(separator: ", "))")
    }
    exit(0)
}
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
        // 이유마다 사용자가 할 일이 다르다. 뭉뚱그려 "설정에서 켜라"고만 하면,
        // 이미 켜 두고 모델을 내려받는 중인 사람에게 거짓말을 하게 된다.
        log("모델을 쓸 수 없다: \(reason)")
        switch reason {
        case .appleIntelligenceNotEnabled:
            log("시스템 설정 → Apple Intelligence & Siri 에서 켜야 한다.")
            log("토글이 비활성이면 같은 화면의 Siri 언어를 English 로 먼저 바꾼다")
            log("(시스템 언어와는 별개 항목이다).")
            exit(2)
        case .modelNotReady:
            // 켜기는 켰고 지금 내려받는 중이다. 할 일은 기다리는 것뿐이라
            // 다시 돌려 보라고만 말하고, 재시도 스크립트가 알아볼 수 있게 코드를 나눈다.
            log("켜져 있고 모델을 내려받는 중이다. 다 받으면 그대로 다시 돌리면 된다.")
            exit(3)
        case .deviceNotEligible:
            log("이 기기는 Apple Intelligence 를 지원하지 않는다.")
            exit(2)
        @unknown default:
            exit(2)
        }
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
        품사를 지킨다 — 동사와 형용사는 "-다"로 끝나는 기본형으로 적는다.
        쉼표 말고 다른 구분 기호는 쓰지 않는다.
        """
    let start = Date()
    var count = 0
    for job in remaining {
        do {
            let korean = try await translate(job, instructions: instructions)
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
