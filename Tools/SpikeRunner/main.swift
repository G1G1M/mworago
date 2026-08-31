import Foundation
import MworagoCore

// M0 스파이크 측정기.
//   (기본)      케이스를 돌려 재현율·정확도를 표로 찍는다
//   --explain   한 낱말이 왜 그 순위인지 점수 내역을 펼친다
//   --sweep     가중치를 훑어 가장 잘 맞는 조합을 찾는다

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

/// 무엇으로 맞았다고 볼지는 정답의 생김새가 정한다.
///   ① 활용형이라 사전형을 따로 적어 뒀으면 → 그 표기로 (辞める가 止める 자리를 뺏는 걸 잡는다)
///   ② 정답에 한자가 있으면 → 표기로 (遺体가 痛い 자리를 뺏는 걸 잡는다)
///   ③ 가나로만 쓰는 낱말이면 → 읽기로 (ありがとう의 사전 표제어는 有難う다)
func makeMatcher(_ testCase: Case) -> (SearchResult) -> Bool {
    let accepted = Set(Deinflector.candidates(for: testCase.reading).map(\.form))
    return { result in
        if testCase.baseForm != testCase.writing {
            return result.entry.writings.contains { $0.text == testCase.baseForm }
        }
        if testCase.writing.contains(where: \.isKanji) {
            return result.entry.writings.contains { $0.text == testCase.writing }
        }
        return result.entry.readings.contains { accepted.contains($0.text) }
    }
}

/// 케이스 전체를 한 가중치로 돌려 몇 개를 맞혔는지 센다.
func evaluate(_ cases: [Case], index: some DictionaryLookup, frequency: FrequencyList?, weights: Ranker.Weights) -> (top1: Int, top3: Int) {
    var top1 = 0, top3 = 0
    for testCase in cases {
        let results = Ranker.search(testCase.hangul, in: index, frequency: frequency, weights: weights)
        let matches = makeMatcher(testCase)
        if results.first.map(matches) ?? false { top1 += 1 }
        if results.prefix(3).contains(where: matches) { top3 += 1 }
    }
    return (top1, top3)
}

// MARK: 입력 처리

let args = CommandLine.arguments
func flagValues(_ name: String) -> [String] {
    guard let i = args.firstIndex(of: name) else { return [] }
    return Array(args[(i + 1)...].prefix { !$0.hasPrefix("--") })
}
let explainWords = flagValues("--explain")
let doSweep = args.contains("--sweep")
let buildCount = flagValues("--build-cases").first.flatMap(Int.init)
let segmentInputs = flagValues("--segment")
let segmentCaseCount = flagValues("--segment-cases").first.flatMap(Int.init)
let doSegmentSweep = args.contains("--segment-sweep")
// 틀린 케이스만 찍는다. 성적표는 얼마나 틀렸는지는 알려 주지만
// **무엇이** 틀렸는지는 안 알려 준다. 원인을 나누려면 실물을 봐야 한다.
let doSegmentFails = args.contains("--segment-fails")
// 활용을 되돌린 결과에 무는 벌점. 낱말 검색에서 정한 값이 분절에도 맞는지는
// 따로 재야 안다 — 분절에서는 이 벌점이 활용형을 조각내는 쪽을 편들 수 있다.
let deinflectionPenalty = flagValues("--deinf-penalty").first.flatMap(Double.init)
// 분절은 앱과 같은 기본값에서 출발한다 — 도구가 다른 값을 쓰면 여기 숫자가 앱 숫자가 아니다.
var tunedWeights = Segmenter.defaultWeights
if let deinflectionPenalty { tunedWeights.deinflectionPenalty = deinflectionPenalty }
// 낱말 검색은 등재형 쪽에 무게를 두는 본래 값을 쓴다(활용 벌점 25).
var wordWeights = Ranker.Weights()
if let deinflectionPenalty { wordWeights.deinflectionPenalty = deinflectionPenalty }
let buildFrequencyLimit = flagValues("--build-frequency").first.flatMap(Int.init)
let buildIndexPath = flagValues("--build-index").first
let useIndexPath = flagValues("--index").first
// --explain 뒤에 오는 낱말들은 위치 인자가 아니다
let positional: [String] = {
    var result: [String] = []
    var i = 1
    while i < args.count {
        if args[i].hasPrefix("--") {
            let consumesValues = args[i] == "--explain" || args[i] == "--build-cases" || args[i] == "--segment" || args[i] == "--cost" || args[i] == "--segment-cases" || args[i] == "--build-frequency" || args[i] == "--freq"
                || args[i] == "--build-index" || args[i] == "--index" || args[i] == "--deinf-penalty"
            i += 1
            if consumesValues { while i < args.count && !args[i].hasPrefix("--") { i += 1 } }
        } else {
            result.append(args[i]); i += 1
        }
    }
    return result
}()
let casesPath = positional.first ?? "Tools/data/spike-cases.tsv"
let dictPath = positional.dropFirst().first ?? "Tools/data/JMdict_e"

let cases = loadCases(casesPath)

func log(_ message: String) { FileHandle.standardError.write(Data((message + "\n").utf8)) }

// --index 를 주면 구워 둔 색인만 연다. XML 은 건드리지도 않는다 — 그게 이 색인의 목적이다.
let index: any DictionaryLookup
var memoryIndexForBuild: DictIndex?

if let useIndexPath, buildIndexPath == nil {
    let openStart = Date()
    index = try DictionaryStore(path: useIndexPath)
    log(String(format: "색인 열기 %@ · %.4f초", useIndexPath, -openStart.timeIntervalSinceNow))
} else {
    log("사전 읽는 중… \(dictPath)")
    let loadStart = Date()
    guard let dictData = FileManager.default.contents(atPath: dictPath) else {
        FileHandle.standardError.write(Data("사전 파일 없음. Tools/fetch-jmdict.sh 를 먼저 실행\n".utf8))
        exit(1)
    }
    let parsed = try JMDictParser.parse(data: dictData)
    let memoryIndex = DictIndex(entries: parsed)
    memoryIndexForBuild = memoryIndex
    index = memoryIndex
    log("표제항 \(memoryIndex.entryCount)개 · 읽기 \(memoryIndex.readingCount)종 · \(String(format: "%.1f", -loadStart.timeIntervalSinceNow))초")

    if let buildIndexPath {
        // 한국어 뜻은 따로 구워 둔 표에서 온다. 없으면 영어 뜻만 실린다.
        var koreanGlosses: [String: String] = [:]
        let koreanPath = "Tools/data/korean-gloss.tsv"
        if let text = try? String(contentsOfFile: koreanPath, encoding: .utf8) {
            var 버린것 = 0
            for line in text.split(separator: "\n") where !line.hasPrefix("#") {
                let columns = line.split(separator: "\t", omittingEmptySubsequences: false)
                guard columns.count >= 3, !columns[2].isEmpty else { continue }
                // 원본은 모델이 말한 그대로 두고, 색인에 실을 때만 다듬는다.
                // 나중에 판단을 바꿔도 다시 굽지 않아도 되고, 무엇이 어떻게 왔는지도 남는다.
                guard let tidied = KoreanGloss.tidy(String(columns[2])) else { 버린것 += 1; continue }
                koreanGlosses["\(columns[0])\t\(columns[1])"] = tidied
            }
            log("한국어 뜻 \(koreanGlosses.count)개 (\(koreanPath))"
                + (버린것 > 0 ? " · 설명문이거나 옮기지 못한 \(버린것)개는 뺐다" : ""))
        } else {
            log("한국어 뜻 없음 — 영어 뜻만 싣는다 (swift run Translator 로 만든다)")
        }

        // 모델이 옮기지 못한 낱말도 손으로 적은 표에서 온다.
        // 가드레일에 막히는 것(594개)과 犬·猫·茶 처럼 이유를 알 수 없이 실패하는 것(297개)이다.
        // 애니 자막에는 그런 말이 흔하다 — 死ぬ·殺す·狙う·馬鹿 는 빈도 최상위권이다.
        // 프롬프트로 우회하면 절반이 틀리게 오고, 짧고 틀린 것은 다듬어서 걸러낼 수 없다.
        let guardrailPath = "Tools/data/guardrail-gloss.tsv"
        if let text = try? String(contentsOfFile: guardrailPath, encoding: .utf8) {
            var 더한것 = 0
            for line in text.split(separator: "\n") where !line.hasPrefix("#") {
                let columns = line.split(separator: "\t", omittingEmptySubsequences: false)
                guard columns.count >= 3, !columns[2].isEmpty else { continue }
                koreanGlosses["\(columns[0])\t\(columns[1])"] = String(columns[2])
                더한것 += 1
            }
            log("손으로 적은 낱말 \(더한것)개 (\(guardrailPath))")
        }

        // 모델이 틀리게 옮긴 것도 손으로 고쳐 둔 표에서 온다.
        // 빈도 상위부터 훑어 보니 **넷 중 하나가 틀리거나 부정확했다** — 그것도 가장 흔한
        // 낱말부터 그랬다(痛い → "뜨겁다" · 肩 → "팔꿈치" · 窓 → "문" · 全然 → "거짓말").
        // 딴 낱말을 대거나 품사가 어긋난 것은 짧고 한국어라 tidy 가 걸러낼 수 없다.
        let correctedPath = "Tools/data/corrected-gloss.tsv"
        if let text = try? String(contentsOfFile: correctedPath, encoding: .utf8) {
            var 고친것 = 0
            for line in text.split(separator: "\n") where !line.hasPrefix("#") {
                let columns = line.split(separator: "\t", omittingEmptySubsequences: false)
                guard columns.count >= 3, !columns[2].isEmpty else { continue }
                koreanGlosses["\(columns[0])\t\(columns[1])"] = String(columns[2])
                고친것 += 1
            }
            log("사람이 고친 뜻 \(고친것)개 (\(correctedPath))")
        }

        // 기능어는 손으로 적은 표에서 온다. 조사·조동사는 번역 대상이 아니어서
        // 뜻 자리에 영어 설명문이 남는데, 화면에서는 "아직 안 된 것"과 구별되지 않는다.
        // **다듬지 않고 그대로 싣는다** — 사람이 적은 것이라 모델을 겨냥한 문을 지날 이유가 없고,
        // 나중에 넣어 모델이 만든 것을 이기게 한다.
        let functionPath = "Tools/data/function-gloss.tsv"
        if let text = try? String(contentsOfFile: functionPath, encoding: .utf8) {
            var 더한것 = 0
            for line in text.split(separator: "\n") where !line.hasPrefix("#") {
                let columns = line.split(separator: "\t", omittingEmptySubsequences: false)
                guard columns.count >= 3, !columns[2].isEmpty else { continue }
                koreanGlosses["\(columns[0])\t\(columns[1])"] = String(columns[2])
                더한것 += 1
            }
            log("기능어 \(더한것)개 (\(functionPath))")
        }

        log("색인 굽는 중… \(buildIndexPath)")
        let bakeStart = Date()
        try DictionaryStore.build(entries: parsed, at: buildIndexPath, koreanGlosses: koreanGlosses)
        let size = (try? FileManager.default.attributesOfItem(atPath: buildIndexPath)[.size] as? Int) ?? 0
        print(String(format: "색인 완료 · %.1fMB · %.1f초", Double(size ?? 0) / 1_048_576, -bakeStart.timeIntervalSinceNow))
        exit(0)
    }
}
_ = memoryIndexForBuild

// 도메인 빈도는 선택 사항이다. 없으면 JMdict 점수만으로 돈다.
// --freq 로 다른 빈도 목록을 물려 비교할 수 있다
// 측정 기준선은 지금 가장 나은 것으로 둔다. JESC(CC BY-SA)는 낱말 검색에서는 거의 같지만
// (140 vs 142) 분절에서 확실히 뒤진다(30.0% vs 42.7%) — 어휘가 3분의 1이고 토크나이저가
// 何 를 なん 으로만 읽어 なに 항목이 없다. 배포용으로는 JESC 가 답이지만 품질을 더 올려야 한다.
// 비교하려면 --freq Tools/data/jesc_freq.tsv
let frequencyPath = flagValues("--freq").first ?? "Tools/data/jpdb_freq.csv"
let frequency: FrequencyList? = {
    let list = FrequencyList(contentsOfFile: frequencyPath)
    guard !list.isEmpty else { return nil }
    return list
}()
log(frequency.map { "도메인 빈도 \($0.count)개 (\(frequencyPath))\n" } ?? "도메인 빈도 없음 — JMdict 점수만 사용\n")

// MARK: --explain

if !explainWords.isEmpty {
    for word in explainWords {
        print("\n입력: \(word)")
        let candidates = Transliterator.candidates(for: word)
        let preview = candidates.prefix(10).map { "\($0.kana)\($0.longVowelsAdded > 0 ? "(장음+\($0.longVowelsAdded))" : "")" }
        print("가나 후보 \(candidates.count)개: \(preview.joined(separator: " · "))\(candidates.count > 10 ? " …" : "")")

        let results = Ranker.search(word, in: index, frequency: frequency)
        print("표제어        읽기          점수   활용     뜻")
        print(String(repeating: "─", count: 76))
        for (i, result) in results.prefix(10).enumerated() {
            let rule = (result.deinflection ?? "—").padded(9)
            print("\(i + 1). \(result.headword.padded(14))\(result.reading.padded(14))\(String(format: "%6.1f", result.score))  \(rule)\(result.entry.glosses.prefix(2).joined(separator: ", "))")
        }
        if results.count > 10 { print("   … 외 \(results.count - 10)개") }
    }
    exit(0)
}

// MARK: --build-frequency
//
// 자막에서 낱말 빈도를 직접 센다.
//
// 지금 쓰는 JPDB 빈도는 재배포 조건이 불분명해 앱에 실을 수 없다. JESC(CC BY-SA 4.0)는
// 영화·TV 자막 279만 문장이라 라이선스가 깨끗하고, 문어체인 Tanaka 와 달리 구어다.
// 읽기가 없다는 문제는 JapaneseReading 이 푼다.

if let buildFrequencyLimit {
    let corpusPath = "Tools/data/split/train"
    guard let handle = FileHandle(forReadingAtPath: corpusPath) else {
        FileHandle.standardError.write(Data("JESC 가 없다. Tools/fetch-jesc.sh 를 먼저 실행\n".utf8))
        exit(1)
    }
    defer { try? handle.close() }

    log("자막 읽는 중… \(corpusPath) (최대 \(buildFrequencyLimit)줄)")
    let start = Date()

    var counts: [FrequencyList.Key: Int] = [:]
    var lineCount = 0
    var leftover = Data()

    while lineCount < buildFrequencyLimit, let chunk = try? handle.read(upToCount: 4 << 20), !chunk.isEmpty {
        var buffer = leftover + chunk
        var lines: [Data] = []
        while let newline = buffer.firstIndex(of: 0x0A) {
            lines.append(buffer[buffer.startIndex..<newline])
            buffer = buffer[buffer.index(after: newline)...]
        }
        leftover = Data(buffer)

        for line in lines {
            lineCount += 1
            if lineCount > buildFrequencyLimit { break }
            guard let text = String(data: line, encoding: .utf8),
                  let tab = text.firstIndex(of: "\t") else { continue }
            // 앞은 영어, 뒤가 일본어
            for token in JapaneseReading.analyze(String(text[text.index(after: tab)...])) {
                counts[FrequencyList.Key(writing: token.surface, reading: token.reading), default: 0] += 1
            }
        }
        if lineCount % 200_000 < 5_000 { log("  \(lineCount)줄…") }
    }

    // 사전에 없는 (표기, 읽기) 쌍을 걸러 보았으나 **결과가 나빴다.**
    // 토크나이저 오류가 빠지는 대신 어휘가 81,218 → 42,946 으로 반토막 나고
    // 정확도가 140 → 138 로 떨어졌다. 노이즈를 지운 것보다 잃은 낱말이 많았다.
    //
    // **거르는 자리는 여기가 아니다.** 등장 횟수로 자르는 편이 낫고(setup-app-resources.sh
    // 가 count>=5 로 자른다), 그 임계값은 재어 보고 정해야 하는데 279만 문장을 다시 세면
    // 한 번에 10분이라 실험이 각오가 된다. 그래서 전량을 내보낸다.
    let ranked = counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key.writing < $1.key.writing }
    log("문장 \(lineCount)줄 · 낱말 \(ranked.count)종 · \(String(format: "%.0f", -start.timeIntervalSinceNow))초")

    // **자른 것을 내보내지 않는다.** 임계값을 바꿔 볼 때마다 279만 문장을 다시 세면
    // 한 번에 10분이라, 고르는 일이 실험이 아니라 각오가 된다. 전량을 내보내고
    // 자르는 것은 쓰는 쪽에서 한다 — count 칸이 그대로 있으니 awk 한 줄이면 된다.
    print("term\treading\tfrequency\tcount")
    for (rank, entry) in ranked.enumerated() {
        print("\(entry.key.writing)\t\(entry.key.reading)\t\(rank + 1)\t\(entry.value)")
    }
    exit(0)
}

// MARK: --segment-cases / --segment-sweep
//
// 분절 정답은 Tanaka Corpus 에서 온다. 사람이 손으로 나눈 낱말 경계라 내가 정할 게 없다.

if segmentCaseCount != nil || doSegmentSweep || doSegmentFails {
    let corpusPath = "Tools/data/examples.utf"
    let count = segmentCaseCount ?? 300
    log("Tanaka Corpus 읽는 중… \(corpusPath)")
    let segmentCases = SegmentCaseBuilder.build(from: corpusPath, limit: count)
    log("분절 케이스 \(segmentCases.count)개")

    guard !segmentCases.isEmpty else {
        FileHandle.standardError.write(Data("케이스를 못 만들었다. Tools/fetch-tanaka.sh 를 먼저 실행\n".utf8))
        exit(1)
    }

    if doSegmentFails {
        print("# 틀린 분절 — 입력\t정답\t내가 나눈 것\t정답표기")
        var wrong = 0
        let weights = tunedWeights
        let cost = flagValues("--cost").first.flatMap(Double.init) ?? Segmenter.defaultSegmentCost
        log("조각 비용 \(cost) · 활용 벌점 \(weights.deinflectionPenalty)")
        for testCase in segmentCases {
            let segments = Segmenter.segment(testCase.hangul, in: index, frequency: frequency,
                                             weights: weights, segmentCost: cost)
            let mine = segments.map(\.hangul)
            guard mine != testCase.pieces else { continue }
            wrong += 1
            print("\(testCase.hangul)\t\(testCase.pieces.joined(separator: " "))\t\(mine.joined(separator: " "))\t\(testCase.words.joined(separator: " "))")
        }
        // 정답이 후보에 아예 없는 조각을 따로 찍는다. 모델은 후보 중에서 고를 뿐이라,
        // 여기 있는 것은 문맥 판별로도 구제되지 않는다.
        for testCase in segmentCases {
            let segments = Segmenter.segment(testCase.hangul, in: index, frequency: frequency,
                                             weights: weights, segmentCost: cost)
            guard segments.map(\.hangul) == testCase.pieces else { continue }
            for (i, segment) in segments.enumerated() where i < testCase.words.count {
                let word = testCase.words[i]
                let forms = Set(Deinflector.candidates(for: testCase.readings[i]).map(\.form))
                guard !segment.results.contains(where: { forms.contains($0.reading) }) else { continue }
                let top = segment.results.prefix(2).map(\.headword).joined(separator: " · ")
                FileHandle.standardError.write(Data("  없음 \(segment.hangul)  정답 \(word)(\(testCase.readings[i]))  나온 것 \(top.isEmpty ? "—" : top)\n".utf8))
            }
        }
        let score = SegmentEval.evaluate(segmentCases, index: index, frequency: frequency,
                                         weights: weights, segmentCost: cost)
        log("틀린 것 \(wrong)/\(segmentCases.count)")
        log(String(format: "경계를 맞힌 조각 %d개 · 1위 %.1f%% · 3위 안 %.1f%% · 후보 안 %.1f%%",
                   score.senseTotal, score.senseRate * 100,
                   score.senseTop3Rate * 100, score.senseAnywhereRate * 100))
        exit(0)
    }

    if !doSegmentSweep {
        print("# 분절 케이스 — 정답 경계는 Tanaka Corpus(EDRDG, CC BY-SA)에서 왔다")
        print("# 한글음차\t정답표기\t정답읽기\t정답조각")
        for testCase in segmentCases {
            print("\(testCase.hangul)\t\(testCase.words.joined(separator: " "))\t\(testCase.readings.joined(separator: " "))\t\(testCase.pieces.joined(separator: " "))")
        }
        exit(0)
    }

    print("조각비용   활용벌점   완전일치   경계F1")
    print(String(repeating: "─", count: 60))
    var best: (cost: Double, unknown: Double, f1: Double, exact: Double)?
    var rows: [(Double, Double, Double, Double)] = []
    // 미지 점수는 축에서 뺐다. 네 값(-200·-350·-500·-800)이 완전일치도 F1 도 똑같아서
    // 이 표본에서는 아무것도 가르지 못한다 — 대신 활용 벌점을 훑는다.
    // 범위는 실패의 76%가 과분할이라는 것을 보고 위로 넓혔다(옛 범위의 끝 145 가 최적이었다).
    for cost in stride(from: 135.0, through: 205.0, by: 5.0) {
        for penalty in [0.0, 5.0, 10.0, 25.0] {
            let unknown = Segmenter.defaultUnknownScore
            var sweepWeights = Segmenter.defaultWeights
            sweepWeights.deinflectionPenalty = penalty
            let score = SegmentEval.evaluate(segmentCases, index: index, frequency: frequency,
                                             weights: sweepWeights,
                                             segmentCost: cost, unknownScore: unknown)
            rows.append((cost, penalty, score.exactRate, score.f1))
            if best == nil || score.exactRate > best!.exact || (score.exactRate == best!.exact && score.f1 > best!.f1) {
                best = (cost, penalty, score.f1, score.exactRate)
            }
        }
    }
    for (cost, unknown, exact, f1) in rows.sorted(by: { $0.2 != $1.2 ? $0.2 > $1.2 : $0.3 > $1.3 }).prefix(12) {
        print(String(format: "%7.0f   %8.0f   %7.1f%%   %6.3f", cost, unknown, exact * 100, f1))
    }
    if let best {
        print(String(format: "\n최고: 조각 비용 %.0f · 활용 벌점 %.0f · 완전일치 %.1f%% · 경계 F1 %.3f",
                     best.cost, best.unknown, best.exact * 100, best.f1))
    }
    exit(0)
}

// MARK: --segment

if !segmentInputs.isEmpty {
    // --cost 로 조각 비용을 바꿔 가며 시험한다
    let cost = flagValues("--cost").first.flatMap(Double.init) ?? Segmenter.defaultSegmentCost
    print("조각 비용 \(cost)")
    for input in segmentInputs {
        let start = Date()
        let segments = Segmenter.segment(input, in: index, frequency: frequency, segmentCost: cost)
        let elapsed = -start.timeIntervalSinceNow * 1000

        let joined = segments.map { segment in
            segment.results.first.map { "\($0.headword)" } ?? "?"
        }.joined(separator: " ")
        print("\n\(input)  →  \(joined)   (\(String(format: "%.1f", elapsed))ms)")

        for segment in segments {
            let top = segment.results.prefix(3).map { result in
                "\(result.headword)(\(result.reading))" + (result.deinflection.map { "·\($0)" } ?? "")
            }.joined(separator: " · ")
            print("  \(segment.hangul.padded(14))\(top.isEmpty ? "— 사전에 없음" : top)")
        }
    }
    exit(0)
}

// MARK: --build-cases
//
// 케이스를 손으로 고르면 "내가 아는 표현"만 모인다. 내가 모르는 실패 유형은 표본에
// 들어오지 않고, 그래서 재현율이 부풀려진다.
//
// 그래서 **낱말은 빈도 데이터가 고르게 하고**, 사람이 하는 일은 음차 규칙을 쓰는 것뿐이다.
// 정답은 뽑힌 그 낱말이라 지어낼 여지가 없다.

if let buildCount {
    guard let frequency else {
        FileHandle.standardError.write(Data("빈도 목록이 필요하다. Tools/fetch-frequency.sh 를 먼저 실행\n".utf8))
        exit(1)
    }
    let existing = Set(cases.map(\.hangul))

    struct Candidate {
        let rank: Int, writing: String, reading: String, hangul: String
    }
    var candidates: [Candidate] = []

    for (rank, writing, reading) in frequency.sortedEntries() {
        // 150위 위쪽은 조사·조동사가 몰려 있어 검색 대상이 아니다
        guard rank >= 150, reading.count >= 2, reading.count <= 7 else { continue }
        guard writing.count >= 2 || writing.contains(where: \.isKanji) else { continue }

        // 사전에 실제로 있는 낱말만. 없으면 채점할 수가 없다
        let inDictionary = index.lookup(reading).contains { hit in
            hit.entry.writings.contains { $0.text == writing } ||
            (hit.entry.writings.isEmpty && writing == reading)
        }
        guard inDictionary else { continue }

        let hangul = KanaToHangul.transliterate(reading)
        guard !hangul.isEmpty, HangulSyllable.decompose(hangul) != nil, !existing.contains(hangul) else { continue }
        candidates.append(Candidate(rank: rank, writing: writing, reading: reading, hangul: hangul))
    }

    // 순위 구간을 로그 스케일로 갈라 고르게 뽑는다. 상위권만 뽑으면 쉬운 문제만 모인다
    let bands = [(150, 500), (500, 1500), (1500, 4000), (4000, 12000)]
    let perBand = buildCount / bands.count
    var picked: [Candidate] = []
    var seenHangul = existing

    for (low, high) in bands {
        let pool = candidates.filter { $0.rank >= low && $0.rank < high }
        guard !pool.isEmpty else { continue }
        // 균등 간격으로 집는다. 난수를 쓰지 않아 돌릴 때마다 같은 표본이 나온다
        let step = max(1, pool.count / perBand)
        for i in stride(from: 0, to: pool.count, by: step) {
            let candidate = pool[i]
            guard seenHangul.insert(candidate.hangul).inserted else { continue }
            picked.append(candidate)
            if picked.count % perBand == 0 && picked.count >= perBand * (bands.firstIndex(where: { $0 == (low, high) })! + 1) { break }
        }
    }

    /// 한글 음차가 무엇을 잃었는지로 난이도를 매긴다
    func tags(_ reading: String, _ hangul: String) -> String {
        var tags: [String] = []
        if reading.contains("っ") { tags.append("촉음") }
        if reading.contains("ん") { tags.append("발음") }
        if reading.contains("つ") || reading.contains("ず") { tags.append("つ") }
        if reading.contains(where: { "ゃゅょ".contains($0) }) { tags.append("요음") }
        if reading.contains(where: { "がぎぐげござじずぜぞだぢづでどばびぶべぼ".contains($0) }) { tags.append("탁음모호") }
        // o단·u단 뒤의 う는 한글에 적히지 않고 사라진다
        let oOrU = Set("おこごそぞとどのほぼぽもよろをょうくぐすずつづぬふぶぷむゆるゅ")
        var previous: Character?
        for character in reading {
            if character == "う", let previous, oOrU.contains(previous) { tags.append("장음"); break }
            previous = character
        }
        return tags.isEmpty ? "기본" : tags.joined(separator: ",")
    }

    print("# 자동 생성 케이스 — 낱말은 JPDB 빈도가 고르고, 음차는 KanaToHangul 이 썼다")
    print("# 한글음차\t정답읽기(가나)\t정답표기\t난이도태그\t사전형표기(활용형일 때)")
    for candidate in picked.sorted(by: { $0.rank < $1.rank }) {
        print("\(candidate.hangul)\t\(candidate.reading)\t\(candidate.writing)\t\(tags(candidate.reading, candidate.hangul))")
    }
    FileHandle.standardError.write(Data("생성 \(picked.count)개 (후보 \(candidates.count)개 중)\n".utf8))
    exit(0)
}

// MARK: --sweep

if doSweep {
    print("가중치 훑는 중…\n")
    var best: (weights: Ranker.Weights, top1: Int, top3: Int)?
    var rows: [(Ranker.Weights, Int, Int)] = []

    for rankPenalty in [0.0, 0.5, 2.0, 5.0] {
        for longVowel in [0.0, 6.0, 12.0, 25.0] {
            for deinflection in [0.0, 25.0, 60.0, 120.0] {
              for domain in [0.0, 0.5, 1.0, 2.0] {
               for jmdict in [0.0, 0.3, 1.0] {
                let weights = Ranker.Weights(rankPenalty: rankPenalty,
                                             longVowelPenalty: longVowel,
                                             deinflectionPenalty: deinflection,
                                             domainWeight: domain,
                                             jmdictWeight: jmdict)
                let (top1, top3) = evaluate(cases, index: index, frequency: frequency, weights: weights)
                rows.append((weights, top1, top3))
                // 1위 정확도가 같으면 3위 안이 더 나은 쪽을 고른다
                if best == nil || top1 > best!.top1 || (top1 == best!.top1 && top3 > best!.top3) {
                    best = (weights, top1, top3)
                }
               }
              }
            }
        }
    }

    print("순서   장음   활용   도메인  JMdict   1위   3위안")
    print(String(repeating: "─", count: 52))
    for (weights, top1, top3) in rows.sorted(by: { $0.1 != $1.1 ? $0.1 > $1.1 : $0.2 > $1.2 }).prefix(14) {
        print(String(format: "%5.1f  %5.1f  %5.1f  %6.1f  %6.1f  %4d  %4d", weights.rankPenalty, weights.longVowelPenalty, weights.deinflectionPenalty, weights.domainWeight, weights.jmdictWeight, top1, top3))
    }
    if let best {
        print("\n최고: 순서 \(best.weights.rankPenalty) · 장음 \(best.weights.longVowelPenalty) · 활용 \(best.weights.deinflectionPenalty) · 도메인 \(best.weights.domainWeight) · JMdict \(best.weights.jmdictWeight)")
        print("      1위 \(best.top1)/\(cases.count) · 3위 안 \(best.top3)/\(cases.count)")
    }
    exit(0)
}

// MARK: 기본 측정

var recall = 0, top1 = 0, top3 = 0, notFound = 0
var failures: [(Case, [SearchResult])] = []
var failedTags: [String: Int] = [:]
var queryTime = 0.0

print("입력          정답            살아남음  1위결과                판정")
print(String(repeating: "─", count: 72))

for testCase in cases {
    let candidates = Transliterator.kanaCandidates(for: testCase.hangul)
    if candidates.contains(testCase.reading) { recall += 1 }

    let start = Date()
    let results = Ranker.search(testCase.hangul, in: index, frequency: frequency, weights: wordWeights)
    queryTime += -start.timeIntervalSinceNow

    let matches = makeMatcher(testCase)
    let hit = results.first.map(matches) ?? false
    let inTop3 = results.prefix(3).contains(where: matches)

    if hit { top1 += 1 }
    if inTop3 { top3 += 1 }
    if results.isEmpty { notFound += 1 }

    let verdict: String
    if hit { verdict = results.first?.deinflection == nil ? "○" : "○ 활용복원" }
    else if inTop3 { verdict = "△ 3위안" }
    else if results.isEmpty { verdict = "✗ 사전없음" }
    else { verdict = "✗ 빗나감" }

    if !hit {
        failures.append((testCase, results))
        for tag in testCase.tags.split(separator: ",") { failedTags[String(tag), default: 0] += 1 }
    }

    let top = results.first.map { "\($0.headword)(\($0.reading))" + ($0.deinflection.map { " ·\($0)" } ?? "") } ?? "—"
    print("\(testCase.hangul.padded(12))\(testCase.reading.padded(14))\(String(results.count).leftPadded(6))  \(top.padded(22))\(verdict)")
}

let total = cases.count
func pct(_ n: Int) -> String { "\(n)/\(total) (\(Int(Double(n) / Double(total) * 100))%)" }

print(String(repeating: "─", count: 72))
print("재현율(후보에 정답 있음)   \(pct(recall))")
print("정확도 (1위가 정답)         \(pct(top1))   ← M0 판정 기준")
print("3위 안                      \(pct(top3))")
print("사전에 아예 없음            \(pct(notFound))")
print("쿼리 평균                   \(String(format: "%.2f", queryTime / Double(total) * 1000))ms")

if !failures.isEmpty {
    print("\n놓친 케이스")
    for (testCase, results) in failures {
        let top = results.prefix(3).map { "\($0.headword)(\($0.reading))" + ($0.deinflection.map { "·\($0)" } ?? "") }.joined(separator: ", ")
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
    /// 한글·가나는 폭이 두 배라 단순 count로는 표가 어긋난다.
    func padded(_ width: Int) -> String {
        let display = reduce(0) { $0 + ($1.isASCII ? 1 : 2) }
        return self + String(repeating: " ", count: max(0, width - display))
    }
    func leftPadded(_ width: Int) -> String {
        String(repeating: " ", count: max(0, width - count)) + self
    }
}
