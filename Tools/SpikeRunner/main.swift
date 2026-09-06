import Foundation
import Translation
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
let glossTopCount = flagValues("--gloss-top").first.flatMap(Int.init)
    ?? (args.contains("--gloss-top") ? 10_000 : nil)
let buildCount = flagValues("--build-cases").first.flatMap(Int.init)
let segmentInputs = flagValues("--segment")
let segmentCaseCount = flagValues("--segment-cases").first.flatMap(Int.init)
let doSegmentSweep = args.contains("--segment-sweep")
// 틀린 케이스만 찍는다. 성적표는 얼마나 틀렸는지는 알려 주지만
// **무엇이** 틀렸는지는 안 알려 준다. 원인을 나누려면 실물을 봐야 한다.
let doSegmentFails = args.contains("--segment-fails")
// 어절 첫머리에 선 조사에 무는 벌점. 0 이면 그 규칙을 쓰지 않는다.
let boundPenalty = flagValues("--bound").first.flatMap(Double.init) ?? Segmenter.defaultBoundPenalty
// 그 벌점만 훑는다. 조각을 찾아본 결과는 벌점과 무관하므로 한 벌을 물려 써서 빠르다.
let doBoundSweep = args.contains("--bound-sweep")
// 자립어 뒤에 조사가 서는 경계에 얹는 보너스. 0 이면 그 규칙을 쓰지 않는다.
let junctionBonus = flagValues("--junction").first.flatMap(Double.init) ?? Segmenter.defaultJunctionBonus
let doJunctionSweep = args.contains("--junction-sweep")
// 활용을 되돌린 결과에 무는 벌점. 낱말 검색에서 정한 값이 분절에도 맞는지는
// 따로 재야 안다 — 분절에서는 이 벌점이 활용형을 조각내는 쪽을 편들 수 있다.
let deinflectionPenalty = flagValues("--deinf-penalty").first.flatMap(Double.init)
// 빈도 목록에 없는 낱말이 기대는 층(JMdict 빈도 태그)의 무게를 훑는다.
//
// **쓰는 자리보다 아래에 선언돼 있었다.** main.swift 의 전역은 적힌 차례대로 초기화되는데,
// 초기화 전에 읽은 `Double?` 은 0 으로 채워진 메모리라 `nil` 이 아니라 **`.some(0.0)`**
// 으로 읽힌다. 그래서 플래그를 주지 않아도 `tunedWeights.jmdictWeight` 가 0 이 되어,
// 측정기가 **앱과 다른 가중치**로 재고 있었다 — 분절 완전일치가 2.4%p 낮게 나왔다.
// 빈도 목록에 없는 낱말이 통째로 0점이 되는 설정이라 차이가 컸다.
let jmdictWeight = flagValues("--jmdict").first.flatMap(Double.init)
// 분절은 앱과 같은 기본값에서 출발한다 — 도구가 다른 값을 쓰면 여기 숫자가 앱 숫자가 아니다.
var tunedWeights = Segmenter.defaultWeights
if let deinflectionPenalty { tunedWeights.deinflectionPenalty = deinflectionPenalty }
if let jmdictWeight { tunedWeights.jmdictWeight = jmdictWeight }
// 낱말 검색은 등재형 쪽에 무게를 두는 본래 값을 쓴다(활용 벌점 25).
var wordWeights = Ranker.Weights()
if let deinflectionPenalty { wordWeights.deinflectionPenalty = deinflectionPenalty }
if let jmdictWeight { wordWeights.jmdictWeight = jmdictWeight }
// 문장 뜻을 모델에게 물어본다. 앱이 부를 것과 같은 재료를 같은 모델에 태운다 —
// 도구가 다른 것을 물으면 여기서 본 답이 앱의 답이 아니다.
let translateInputs = flagValues("--translate")
// 자막 문장을 줄줄이 태워 **몇 개나 막히는지** 센다. 문장 뜻은 사람이 채점해야 알지만,
// 막힌 것은 세면 안다 — 그리고 막히는 비율이 크면 뜻이 좋고 나쁘고는 따질 일이 아니다.
let translateCaseCount = flagValues("--translate-cases").first.flatMap(Int.init)
// 한 글자씩 늘려 가며 분절 시간을 잰다. 화면은 글자를 칠 때마다 다시 찾으므로,
// **한 번의 검색이 아니라 치는 동안의 비용**이 사용자가 느끼는 것이다.
let typingInput = flagValues("--typing").first
// 조사에게 돌려주는 조각 비용을 훑는다.
// 애플 번역기(Translation 프레임워크)로도 같은 문장을 태운다.
// 온디바이스 모델은 만들어 내는 물건이라 안전 필터가 옮기는 일까지 막는데,
// 번역기는 옮기는 것이 본업이다. 어느 쪽이 이 앱에 맞는지는 나란히 놓고 봐야 안다.
let mtCaseCount = flagValues("--mt-cases").first.flatMap(Int.init)
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
                || args[i] == "--translate" || args[i] == "--translate-cases" || args[i] == "--typing"
                || args[i] == "--jmdict" || args[i] == "--mt-cases" || args[i] == "--bound" || args[i] == "--junction" || args[i] == "--mt-share"
                || args[i] == "--gloss-top"
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
        FileHandle.standardError.write(Data("사전 파일 없음. Tools/fetch/fetch-jmdict.sh 를 먼저 실행\n".utf8))
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

// MARK: --gloss-top
//
// **1위 카드에 한국어 뜻이 뜨는가.**
//
// `gloss-holes.sh` 는 잣대를 둘 쓰는데 둘 다 이 물음에는 답하지 못한다. 하나는
// 굽기의 진도(빈도 목록의 표기·읽기 쌍)이고, 다른 하나는 읽기로 닿는 표제항 **전부**라
// 동음이의어 꼬리를 다 센다(`は` 11개 · `し` 40개). 꼬리는 대개 카드의 `다른 뜻 N` 에
// 들어가지 1위로는 잘 안 올라온다. 그래서 두 숫자 사이가 98.8% 와 68.2% 로 벌어져 있고,
// **그 사이 어디가 사용자가 겪는 값인지**를 아무도 몰랐다.
//
// 여기서는 순위를 실제로 매겨 본다. 빈도 목록의 낱말을 **그 소리대로 쳐 보고**
// (`KanaToHangul` 로 음차해서 앱과 같은 `Ranker.search` 에 넣는다) 1위로 올라온 카드에
// 한국어 뜻이 있는지 센다. 앱이 하는 일과 같은 길이다.
//
// **1위가 그 낱말인지는 묻지 않는다.** 그것은 정확도이고 이미 M0 가 잰다. 여기서 묻는
// 것은 "치면 한국어가 뜨는가" 하나다 — 1위가 딴 낱말이어도 뜻이 있으면 화면은 채워진다.

if let glossTopCount {
    guard let frequency else {
        FileHandle.standardError.write(Data("빈도 목록이 있어야 한다 (--freq)\n".utf8))
        exit(1)
    }
    // **구운 색인을 물려야 한다.** 기본은 JMdict 원본을 메모리에 올린 것이라 한국어 뜻이
    // 아예 없다 — 처음 돌렸을 때 모든 구간이 0.0% 로 나와서 알았다.
    guard useIndexPath != nil else {
        FileHandle.standardError.write(Data(
            "구운 색인을 물려야 한다: --index MworagoApp/Resources/mworago-dict.db\n".utf8))
        exit(1)
    }

    // 같은 음차로 겹치는 줄이 있다(`私·わたし` 와 `渡し·わたし`). 가장 높은 순위로 센다.
    var bestRank: [String: Int] = [:]
    for entry in frequency.sortedEntries() {
        guard entry.rank <= glossTopCount else { break }
        let hangul = KanaToHangul.transliterate(entry.reading)
        guard !hangul.isEmpty else { continue }
        if bestRank[hangul].map({ entry.rank < $0 }) ?? true { bestRank[hangul] = entry.rank }
    }
    log("음차해서 쳐 볼 낱말 \(bestRank.count)개 (빈도 1~\(glossTopCount)위)\n")

    let bands: [(Int, Int)] = [(1, 1000), (1000, 5000), (5000, 10000), (10000, 30000), (30000, .max)]
    var tried = [Int](repeating: 0, count: bands.count)
    var covered = [Int](repeating: 0, count: bands.count)
    var byHand = [Int](repeating: 0, count: bands.count)   // 기능어·접사 — 손으로 적을 자리
    var byMachine = [Int](repeating: 0, count: bands.count) // 그 밖 — 구워서 메울 자리
    var katakana = [Int](repeating: 0, count: bands.count)  // 그중 가타카나 외래어
    var notFound = [Int](repeating: 0, count: bands.count)  // 1위가 아예 안 나온 것
    var handList: [(Int, String, String)] = []
    var machineList: [(Int, String, String)] = []

    for (hangul, rank) in bestRank.sorted(by: { $0.value < $1.value }) {
        let band = bands.firstIndex { rank >= $0.0 && rank < $0.1 } ?? bands.count - 1
        tried[band] += 1
        guard let top = Ranker.search(hangul, in: index, frequency: frequency).first else {
            notFound[band] += 1
            continue
        }
        if !(top.entry.koreanGloss ?? "").isEmpty {
            covered[band] += 1
            continue
        }
        // **메울 길이 둘로 갈린다.** 조사·조동사·접사는 낱말 뜻으로 옮길 수가 없어
        // 굽기가 일부러 건너뛴다 — `function-gloss.tsv` 에 손으로 적을 자리다.
        // 그 밖은 기계가 구울 수 있는데 아직 안 구워졌거나, 후보가 여럿이라 막힌 것이다.
        let 손 = top.entry.wordClass == .function || top.entry.wordClass == .affix
        if 손 {
            byHand[band] += 1
            // **적을 자리의 열쇠까지 찍는다.** 손으로 적는 표는 `표기 + 읽기` 로 붙는데
            // (`DictionaryStore.build`), 그 표기가 표제어와 다를 수 있다 —
            // 표기가 없는 낱말은 읽기가 곧 표기다. 열쇠를 모르면 적어도 안 붙는다.
            let key = (top.entry.usableWritings.first?.text ?? top.reading) + "\t" + top.reading
            handList.append((rank, hangul, key))
        } else {
            byMachine[band] += 1
            // **가타카나 표제어는 구우면 메워질 자리다.** 그 밖은 1위가 엉뚱한 낱말이라
            // 잡힌 것이 섞여 있어(`시테`→`仕手`) 뜻을 구워도 안 나아진다.
            if top.headword.unicodeScalars.allSatisfy({ $0.value >= 0x30A0 && $0.value <= 0x30FF }) {
                katakana[band] += 1
            }
            if machineList.count < 40 { machineList.append((rank, hangul, top.headword)) }
        }
    }

    func row(_ label: String, _ a: Int, _ b: Int, _ c: Int, _ d: Int, _ e: Int) {
        let rate = a - e > 0 ? 100 * Double(b) / Double(a - e) : 0
        print("\(label.padded(16))\(String(a).padded(9))\(String(b).padded(9))"
              + "\(String(c).padded(9))\(String(d).padded(9))\(String(e).padded(8))"
              + String(format: "%5.1f%%", rate))
    }

    print("\n1위 카드에 한국어 뜻이 뜨는가 — **소리대로 쳐 보고 센다**\n")
    print("\("순위 구간".padded(16))\("쳐 봄".padded(9))\("뜻 뜸".padded(9))"
          + "\("손으로".padded(9))\("구워서".padded(9))\("못 찾음".padded(8))비율")
    print(String(repeating: "─", count: 66))
    var t = 0, c = 0, h = 0, m = 0, n = 0
    for (i, band) in bands.enumerated() where tried[i] > 0 {
        t += tried[i]; c += covered[i]; h += byHand[i]; m += byMachine[i]; n += notFound[i]
        let label = band.1 == .max ? "\(band.0.formatted())~"
                                   : "\(band.0.formatted())~\(band.1.formatted())"
        row(label, tried[i], covered[i], byHand[i], byMachine[i], notFound[i])
    }
    print(String(repeating: "─", count: 66))
    row("합계", t, c, h, m, n)

    print("""

        비율은 **1위가 나온 것 중** 뜻이 뜬 비율이다(`못 찾음` 은 뺐다).
        `못 찾음` 은 뜻이 아니라 검색 쪽 자리다 — 빈도 목록에 토크나이저가 흘린
        활용 조각(`잇` · `낫` · `얏`)이 섞여 있어 그것들이 여기 잡힌다.

        `손으로` 는 조사·조동사·접사다. 굽기가 **일부러** 건너뛴다 — 낱말 뜻으로
        옮길 수가 없어서다(`の` → "indicates possessive"). `function-gloss.tsv` 자리다.
        `구워서` 는 기계가 옮길 수 있는데 아직 안 된 것이거나, 한 읽기에 후보가
        여럿이라 굽기가 막아 둔 것이다(`guardrail-gloss.tsv` 자리).
        """)

    if !handList.isEmpty {
        let handLimit = args.contains("--gloss-top-hand") ? handList.count : 20
        print("\n손으로 적을 자리 — 흔한 것부터 \(handLimit)개")
        print("(순위 · 친 소리 · **적을 열쇠**(표기⇥읽기) · 영어 뜻)")
        for (rank, hangul, key) in handList.prefix(handLimit) {
            let english = Ranker.search(hangul, in: index, frequency: frequency).first?
                .entry.glosses.prefix(2).joined(separator: " / ") ?? ""
            print("  \(String(rank).padded(7))\(hangul.padded(14))\(key)\t\(english)")
        }
    }
    let kata = katakana.reduce(0, +)
    print("\n`구워서` \(m)개 중 가타카나 외래어가 \(kata)개다 — 구우면 메워질 자리.")
    print("나머지 \(m - kata)개에는 1위가 엉뚱한 낱말이라 잡힌 것이 섞여 있다.")

    if !machineList.isEmpty {
        print("\n구워서 메울 자리 — 흔한 것부터 스물")
        for (rank, hangul, headword) in machineList.prefix(20) {
            print("  \(String(rank).padded(7))\(hangul.padded(16))\(headword)")
        }
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
        FileHandle.standardError.write(Data("JESC 가 없다. Tools/fetch/fetch-jesc.sh 를 먼저 실행\n".utf8))
        exit(1)
    }
    defer { try? handle.close() }

    // **복합 표현을 한 덩어리로도 센다.**
    //
    // 토크나이저는 낱말 하나씩만 내놓는다. 그래서 `ではない`·`そんなに`·`すぐに` 처럼
    // **사전에는 한 낱말로 실려 있는데 토큰으로는 여럿인 것**이 빈도 목록에 아예 안 실렸고,
    // 점수가 10점(JMdict 태그 점수)에 머물렀다. 쪼갠 조각들은 100점대라 반드시 진다 —
    // `そんなに`(10) 대 `そんな`(79.8)+`に`(110.5).
    //
    // 틀린 분절 153건 가운데 129건이 **정답 낱말 하나가 빈도 목록에 없는** 문장이었다.
    // 점수나 조각 비용으로 풀 자리가 아니라 세는 자리에서 안 센 것이다.
    //
    // 이어진 토큰 둘~넷을 붙여 보고 **사전에 그 낱말이 있을 때만** 한 번 더 센다.
    // 아무 이어짐이나 세면 말뭉치에 없는 낱말이 생긴다.
    var compoundKeys = Set<FrequencyList.Key>()
    if let dictData = FileManager.default.contents(atPath: dictPath),
       let entries = try? JMDictParser.parse(data: dictData) {
        for entry in entries {
            for reading in entry.readings {
                // 가나로 쓰는 낱말은 읽기가 곧 표기다. `uk` 인 것도 그렇게 쓰인다
                // (`何時も` 는 자막에 `いつも` 로 적힌다).
                if entry.usableWritings.isEmpty || entry.usuallyKana {
                    compoundKeys.insert(.init(writing: reading.text, reading: reading.text))
                }
                for writing in entry.usableWritings {
                    compoundKeys.insert(.init(writing: writing.text, reading: reading.text))
                }
            }
        }
        log("사전이 아는 (표기·읽기) 짝 \(compoundKeys.count)개 — 이어진 토큰이 이 안에 들면 함께 센다")
    }

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
            let tokens = JapaneseReading.analyze(String(text[text.index(after: tab)...]))
            for token in tokens {
                counts[FrequencyList.Key(writing: token.surface, reading: token.reading), default: 0] += 1
            }
            // 이어진 토큰 둘~넷이 사전에 한 낱말로 실려 있으면 그것도 한 번 센다.
            // 넷까지인 것은 그보다 긴 표제항이 드물고, 길수록 헛되이 붙는 값만 늘어서다.
            for span in 2...4 where tokens.count >= span {
                for from in 0...(tokens.count - span) {
                    let piece = tokens[from..<(from + span)]
                    let key = FrequencyList.Key(writing: piece.map(\.surface).joined(),
                                                reading: piece.map(\.reading).joined())
                    if compoundKeys.contains(key) { counts[key, default: 0] += 1 }
                }
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

if segmentCaseCount != nil || doSegmentSweep || doSegmentFails || doBoundSweep || doJunctionSweep {
    let corpusPath = "Tools/data/examples.utf"
    let count = segmentCaseCount ?? 300
    log("Tanaka Corpus 읽는 중… \(corpusPath)")
    let segmentCases = SegmentCaseBuilder.build(from: corpusPath, limit: count)
    log("분절 케이스 \(segmentCases.count)개")

    guard !segmentCases.isEmpty else {
        FileHandle.standardError.write(Data("케이스를 못 만들었다. Tools/fetch/fetch-tanaka.sh 를 먼저 실행\n".utf8))
        exit(1)
    }

    if doSegmentFails {
        print("# 틀린 분절 — 입력\t정답\t내가 나눈 것\t정답표기")
        var wrong = 0
        let weights = tunedWeights
        let cost = flagValues("--cost").first.flatMap(Double.init) ?? Segmenter.defaultSegmentCost
        log("조각 비용 \(cost) · 활용 벌점 \(weights.deinflectionPenalty)"
            + " · 첫머리 조사 벌점 \(boundPenalty) · 조사 경계 보너스 \(junctionBonus)")
        for testCase in segmentCases {
            let segments = Segmenter.segment(testCase.hangul, in: index, frequency: frequency,
                                             weights: weights, segmentCost: cost,
                                             boundPenalty: boundPenalty,
                                             junctionBonus: junctionBonus)
            let mine = segments.map(\.hangul)
            guard mine != testCase.pieces else { continue }
            wrong += 1
            print("\(testCase.hangul)\t\(testCase.pieces.joined(separator: " "))\t\(mine.joined(separator: " "))\t\(testCase.words.joined(separator: " "))")
        }
        // 정답이 후보에 아예 없는 조각을 따로 찍는다. 모델은 후보 중에서 고를 뿐이라,
        // 여기 있는 것은 문맥 판별로도 구제되지 않는다.
        for testCase in segmentCases {
            let segments = Segmenter.segment(testCase.hangul, in: index, frequency: frequency,
                                             weights: weights, segmentCost: cost,
                                             boundPenalty: boundPenalty,
                                             junctionBonus: junctionBonus)
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
                                         weights: weights, segmentCost: cost,
                                         boundPenalty: boundPenalty,
                                         junctionBonus: junctionBonus)
        log("틀린 것 \(wrong)/\(segmentCases.count)")
        log(String(format: "경계를 맞힌 조각 %d개 · 1위 %.1f%% · 3위 안 %.1f%% · 후보 안 %.1f%%",
                   score.senseTotal, score.senseRate * 100,
                   score.senseTop3Rate * 100, score.senseAnywhereRate * 100))
        exit(0)
    }

    if doJunctionSweep {
        // 조각을 찾아본 결과는 이 보너스와 무관하므로 한 벌을 물려 쓴다.
        let sweepCache = SearchCache(limit: .max)
        let weights = tunedWeights
        let cost = flagValues("--cost").first.flatMap(Double.init) ?? Segmenter.defaultSegmentCost
        print("조사 경계 보너스   완전일치   경계F1   1위")
        print(String(repeating: "─", count: 50))
        for bonus in [0.0, 4.0, 6.0, 8.0, 10.0, 12.0, 14.0, 16.0, 18.0, 20.0, 25.0] {
            let score = SegmentEval.evaluate(segmentCases, index: index, frequency: frequency,
                                             weights: weights, segmentCost: cost,
                                             boundPenalty: boundPenalty,
                                             junctionBonus: bonus, cache: sweepCache)
            print(String(format: "%13.0f   %7.1f%%   %6.3f   %5.1f%%",
                         bonus, score.exactRate * 100, score.f1, score.senseRate * 100))
        }
        exit(0)
    }

    if doBoundSweep {
        // **한 벌로 다 훑는다.** 조각을 찾아본 결과는 가중치가 정하고, 이 벌점은
        // 나눌 자리만 정한다. 그래서 캐시 하나를 물려 쓰면 사전 조회가 한 번으로 끝난다.
        let sweepCache = SearchCache(limit: .max)
        let weights = tunedWeights
        let cost = flagValues("--cost").first.flatMap(Double.init) ?? Segmenter.defaultSegmentCost
        print("첫머리 조사 벌점   완전일치   경계F1   1위")
        print(String(repeating: "─", count: 52))
        for penalty in [0.0, 10.0, 20.0, 40.0, 80.0, 160.0, 320.0] {
            let score = SegmentEval.evaluate(segmentCases, index: index, frequency: frequency,
                                             weights: weights, segmentCost: cost,
                                             boundPenalty: penalty,
                                             junctionBonus: junctionBonus, cache: sweepCache)
            print(String(format: "%13.0f   %7.1f%%   %6.3f   %5.1f%%",
                         penalty, score.exactRate * 100, score.f1, score.senseRate * 100))
        }
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
    // **범위는 재면서 옮긴다.** 한때 최적이 하한(135)에서 나왔는데, 그것은 범위 밖에
    // 더 좋은 값이 있다는 신호다. 외래어가 빈도 점수를 되찾으면서 조각들의 점수가
    // 전반적으로 올라, 조각 비용도 함께 내려가야 균형이 맞는다.
    for penalty in [0.0, 5.0, 10.0, 15.0, 20.0, 25.0] {
        // 조각을 찾아본 결과는 가중치가 같으면 같다. 비용을 훑는 동안 한 벌을 물려 쓴다 —
        // 15배쯤 빨라져서 훑기가 몇 시간이 아니라 몇 분이 된다.
        let sweepCache = SearchCache(limit: .max)
        for cost in stride(from: 90.0, through: 160.0, by: 5.0) {
            let unknown = Segmenter.defaultUnknownScore
            var sweepWeights = Segmenter.defaultWeights
            sweepWeights.deinflectionPenalty = penalty
            let score = SegmentEval.evaluate(segmentCases, index: index, frequency: frequency,
                                             weights: sweepWeights,
                                             segmentCost: cost, unknownScore: unknown,
                                             boundPenalty: boundPenalty,
                                             junctionBonus: junctionBonus, cache: sweepCache)
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

// MARK: --typing

if let typingInput {
    print("글자 수  누적 입력                        분절 시간")
    print(String(repeating: "─", count: 62))
    var total = 0.0
    let characters = Array(typingInput)
    // 화면과 같은 조건으로 잰다 — 앱은 조각을 찾아본 결과를 들고 있다.
    let cache = args.contains("--no-cache") ? nil : SearchCache()
    for count in 1...characters.count {
        let prefix = String(characters[0..<count])
        let start = Date()
        _ = Segmenter.segment(prefix, in: index, frequency: frequency, cache: cache)
        let elapsed = -start.timeIntervalSinceNow * 1000
        total += elapsed
        // 화면이 60번 그려지는 사이가 16ms 다. 그보다 오래 걸리면 치는 손이 기다린다.
        let mark = elapsed > 16 ? " ←" : ""
        print(String(format: "%5d    %@%@%8.1fms%@", count, prefix,
                     String(repeating: " ", count: max(0, 30 - prefix.count * 2)), elapsed, mark))
    }
    print(String(format: "\n다 치는 동안 %.0fms · 글자당 평균 %.1fms", total, total / Double(characters.count)))
    exit(0)
}

// MARK: --translate
//
// 문장 뜻을 온디바이스 모델에게 물어본다. 낱말 뜻과 달리 문장은 미리 구울 수가 없어서
// (조합이 무한하다) 런타임에 묻는 수밖에 없다. 낱말을 구울 때 이 모델은 한국어가
// 지원 언어에서 빠져 있고 죽음·폭력이 든 말이 막혀 EXAONE 으로 갈아탔었다.
// 문장에서 그 벽이 어떻게 나타나는지는 태워 봐야 안다.

if !translateInputs.isEmpty {
    #if canImport(FoundationModels)
    if #available(macOS 26.0, *) {
        log(SentenceTranslator.isAvailable ? "모델 준비됨" : "모델을 쓸 수 없다")
        for input in translateInputs {
            let segments = Segmenter.segment(input, in: index, frequency: frequency)
            print("\n입력: \(input)")
            guard let prompt = SentencePrompt.prompt(for: segments) else {
                print("  물을 것이 없다 (조각이 하나뿐)")
                continue
            }
            print(prompt.split(separator: "\n").map { "  | " + $0 }.joined(separator: "\n"))
            let start = Date()
            do {
                let korean = try await SentenceTranslator.translate(segments)
                print(String(format: "  → %@  (%.1f초)", korean ?? "(빈 답)", -start.timeIntervalSinceNow))
            } catch {
                // 무엇에 막혔는지가 이 도구의 존재 이유다. 앱에서는 조용히 삼킬 것을 여기서는 적는다.
                print(String(format: "  ✗ %@  (%.1f초)", String(describing: error), -start.timeIntervalSinceNow))
            }
        }
    } else {
        log("이 맥은 macOS 26 이 아니다.")
    }
    #else
    log("이 SDK 에는 FoundationModels 가 없다.")
    #endif
    exit(0)
}

// MARK: --mt-cases
//
// 애플 번역기로 문장을 옮긴다. 우리가 되살린 원문을 그대로 넘긴다 —
// 번역기는 사전 뜻도 품사도 받지 않으므로, 넘길 수 있는 것은 문장 한 줄뿐이다.

if let mtCaseCount {
    // 세션을 곧바로 여는 이 이니셜라이저는 macOS 26 것이다. 앱에서는 iOS 18 부터
    // `.translationTask` 로 세션을 받으므로, 배포 타깃을 올릴 이유는 되지 않는다.
    if #available(macOS 26.0, *) {
        let cases = SegmentCaseBuilder.build(from: "Tools/data/examples.utf", limit: mtCaseCount)
        log("문장 \(cases.count)개")
        let session = TranslationSession(installedSource: Locale.Language(identifier: "ja"),
                                         target: Locale.Language(identifier: "ko"))
        var 옮긴것 = 0, 막힌것 = 0
        var 시간 = 0.0
        for testCase in cases {
            let segments = Segmenter.segment(testCase.hangul, in: index, frequency: frequency)
            // 앱이 화면에 되살려 놓는 그 문장을 넘긴다. 사용자가 친 것은 한글이지만
            // 번역기가 받을 수 있는 것은 일본어다.
            let parts = segments.filter { !$0.isWhole }
            var japanese = args.contains("--mt-kana") ? parts.kana
                         : args.contains("--mt-kanji") ? parts.japanese
                         : parts.forTranslation(kanjiShare: flagValues("--mt-share").first.flatMap(Double.init) ?? Segment.defaultKanjiShare)
            // **마침표를 붙여 보고 견준다.** 번역기는 문장부호가 있는 글로 배웠는데
            // 우리는 토막을 던지고 있다. 그 차이가 값을 하는지는 재야 안다.
            //
            // **재 보니 값을 하지 않는다.** 문장 25개 중 11개가 달라졌지만 대부분은
            // 한국어 마침표가 붙은 것뿐이고, 뜻이 바뀐 자리는 좋아진 것 하나
            // (`和服` → 한복에서 기모노로)와 나빠진 것 둘(`好きだ` 가 "좋아한다"에서
            // "좋아했다"로, `とっつきやすい` 가 "사람이다"에서 "사람이었다"로 —
            // 시제가 흔들렸다)이었다. 그래서 앱에는 넣지 않았다.
            //
            // 플래그는 남겨 둔다. 다음에 같은 생각을 하는 사람이 다시 재지 않아도 되게.
            if args.contains("--mt-period"), !japanese.isEmpty,
               !"。！？".contains(japanese.last!) {
                japanese += "。"
            }
            let start = Date()
            do {
                let response = try await session.translate(japanese)
                시간 += -start.timeIntervalSinceNow
                옮긴것 += 1
                print("○ \(testCase.words.joined(separator: " "))\t\(japanese)\t\(response.targetText)")
            } catch {
                시간 += -start.timeIntervalSinceNow
                막힌것 += 1
                print("✗ \(testCase.words.joined(separator: " "))\t\(japanese)\t\(String(describing: error).prefix(60))")
            }
        }
        let 물어본것 = 옮긴것 + 막힌것
        log("")
        log(String(format: "옮김 %d (%.0f%%) · 못 옮김 %d · 문장당 %.2f초",
                   옮긴것, Double(옮긴것) / Double(max(1, 물어본것)) * 100, 막힌것,
                   시간 / Double(max(1, 물어본것))))
    } else {
        log("이 맥은 macOS 26 이 아니다.")
    }
    exit(0)
}

// MARK: --translate-cases

if let translateCaseCount {
    #if canImport(FoundationModels)
    if #available(macOS 26.0, *) {
        let cases = SegmentCaseBuilder.build(from: "Tools/data/examples.utf", limit: translateCaseCount)
        log("문장 \(cases.count)개")
        var 옮긴것 = 0, 막힌것 = 0, 물을것없음 = 0, 그밖에 = 0
        var 시간 = 0.0
        for testCase in cases {
            let segments = Segmenter.segment(testCase.hangul, in: index, frequency: frequency)
            guard SentencePrompt.materials(for: segments) != nil else { 물을것없음 += 1; continue }
            let start = Date()
            do {
                let korean = try await SentenceTranslator.translate(segments)
                시간 += -start.timeIntervalSinceNow
                옮긴것 += 1
                print("○ \(testCase.words.joined(separator: " "))\t\(korean ?? "")")
            } catch {
                시간 += -start.timeIntervalSinceNow
                let 막힘 = String(describing: error).contains("guardrail")
                if 막힘 { 막힌것 += 1 } else { 그밖에 += 1 }
                print("\(막힘 ? "✗" : "?") \(testCase.words.joined(separator: " "))\t\(막힘 ? "막힘" : String(describing: error).prefix(60))")
            }
        }
        let 물어본것 = 옮긴것 + 막힌것 + 그밖에
        log("")
        log("물어본 문장 \(물어본것)개 · 물을 것 없던 문장 \(물을것없음)개")
        if 물어본것 > 0 {
            log(String(format: "  옮김 %d (%.0f%%) · 막힘 %d (%.0f%%) · 그 밖 %d",
                       옮긴것, Double(옮긴것) / Double(물어본것) * 100,
                       막힌것, Double(막힌것) / Double(물어본것) * 100, 그밖에))
            log(String(format: "  문장당 %.1f초", 시간 / Double(물어본것)))
        }
    }
    #endif
    exit(0)
}

// MARK: --segment

if !segmentInputs.isEmpty {
    // --cost 로 조각 비용을 바꿔 가며 시험한다
    let cost = flagValues("--cost").first.flatMap(Double.init) ?? Segmenter.defaultSegmentCost
    print("조각 비용 \(cost)")
    for input in segmentInputs {
        let start = Date()
        let segments = Segmenter.segment(input, in: index, frequency: frequency, segmentCost: cost,
                                         boundPenalty: boundPenalty, junctionBonus: junctionBonus)
        let elapsed = -start.timeIntervalSinceNow * 1000

        let joined = segments.map { segment in
            segment.results.first.map { "\($0.headword)" } ?? "?"
        }.joined(separator: " ")
        print("\n\(input)  →  \(joined)   (\(String(format: "%.1f", elapsed))ms)")
        // **번역기가 받는 글자는 화면에 보이는 것과 다르다.** 사전이 `uk` 라고 한 낱말을
        // 어느 쪽으로 넘기는지가 뜻 줄을 좌우하는데, 조각 목록만 봐서는 안 보인다.
        let parts = segments.filter { !$0.isWhole }
        print("  번역기에 넘길 원문   \(parts.forTranslation())")

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
        FileHandle.standardError.write(Data("빈도 목록이 필요하다. Tools/fetch/fetch-frequency.sh 를 먼저 실행\n".utf8))
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
