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

/// 건너뛴 기능어. 번역하지 않을 뿐 화면에는 나오므로, 무엇이 자주 나오는지는 알아야 한다.
struct Skipped {
    let writing: String
    let reading: String
    let wordClass: WordClass
    let english: [String]
}

func loadJobs(indexPath: String, frequencyPath: String, limit: Int,
              maxRank: Int? = nil, skipped: inout [Skipped]) throws -> [Job] {
    let store = try DictionaryStore(path: indexPath)
    let frequency = FrequencyList(contentsOfFile: frequencyPath)
    guard !frequency.isEmpty else { throw Failure("빈도 목록이 비어 있다: \(frequencyPath)") }

    var jobs: [Job] = []
    var seen = Set<String>()

    for entry in frequency.sortedEntries() {
        guard jobs.count < limit else { break }
        // 순위 상한을 넘으면 더 볼 것이 없다 — 목록이 순위순이다.
        if let maxRank, entry.rank > maxRank { break }
        // 사전에 있고 영어 뜻이 달린 것만 번역할 수 있다.
        //
        // **후보가 하나뿐이면 고를 것이 없다.** 아래 규칙이 "표기가 딸린 항목은
        // 가나 빈도 줄로 받지 않는다"고 막는 까닭은 어느 항목인지 고를 수 없어서인데,
        // 그 읽기를 가진 항목이 애초에 하나면 고르는 일 자체가 없다. 이것을 막고
        // 있어서 `ません`(55위) · `のか`(59위) · `ても`(117위) · `ために`(170위)
        // 같은 것들이 통째로 빠져 있었다 — 말뭉치가 가나로 적고 사전은 한자로
        // 실어서(`為に`) 표기가 안 만나는 부류다.
        let byReading = store.lookup(entry.reading).filter {
            $0.reading == entry.reading && !$0.entry.glosses.isEmpty
        }
        let onlyCandidate = byReading.count == 1

        // **외래어는 읽기끼리 안 맞는다.**
        //
        // 빈도 목록이 가타카나 낱말을 **히라가나 읽기**로 싣는다 —
        // `カード / かあど` · `システム / しすてむ` · `チーム / ちいむ`.
        // 사전은 그 낱말의 읽기를 `カード` 로 싣는다. 그래서 아래 `hit.reading ==
        // entry.reading` 이 통째로 어긋나 **외래어 968개가 굽기에서 빠져 있었다**
        // (조회 자체는 닿는다 — 색인 키가 둘 다 `かーど` 로 접히기 때문이다).
        //
        // **읽기를 접어서 맞추면 안 된다.** 그러면 `でも`(조사)가 `デモ`(시위)를 물어
        // 온다 — 아래 주석이 그 자리다. 대신 **빈도 줄의 표기**로 맞춘다. 그 표기가
        // 가타카나면 그것이 곧 그 낱말의 읽기이므로 어긋날 자리가 없다.
        let 외래어표기 = !entry.writing.isEmpty && entry.writing.unicodeScalars.allSatisfy {
            (0x30A0...0x30FF).contains($0.value)
        }
        guard let hit = store.lookup(entry.reading).first(where: { hit in
            if 외래어표기, hit.reading == entry.writing, !hit.entry.glosses.isEmpty { return true }
            return 
            // **가나 종류까지 같아야 한다.** 색인 조회 키는 히라가나로 정규화돼 있어서
            // でも 로 찾으면 デモ(시위)가 함께 걸려 나오고, 표기 없는 항목끼리 비교하면
            // 그대로 통과해 버린다. 실제로 でも 의 뜻이 "demonstration, protest" 였고
            // もの 는 "mono" 였다 — 모델은 받은 대로 옮겼을 뿐이다.
            hit.reading == entry.reading
                && (hit.entry.usableWritings.contains { $0.text == entry.writing }
                    // **가나로만 쓴 낱말이라도 표기가 딸린 항목은 받지 않는다.**
                    //
                    // 한때 받아 봤다. ある · くる · できる 같은 최상위 빈도 2,635개가
                    // 한자 표기(有る · 来る)가 있다는 이유로 빠져 있어서였다. 그런데
                    // **형태만으로는 어느 항목인지 고를 수가 없다.**
                    //
                    //   の  → [野] [없음=조사] [箆] [幅]  → 첫 항목을 집어 "지대"
                    //   が  → [蛾] [없음=조사] [絵] [我]  → "나방"
                    //   なる → [生る] [成る] [鳴る]        → "맺다" (되다가 아니라)
                    //   こと → [琴] [事] [古都]           → "거문고"
                    //
                    // 뜻이 없는 것은 "아직 안 된 것"으로 보이지만 **틀린 뜻은 사람을 속인다.**
                    // 이런 낱말은 손으로 적는다 — guardrail-gloss.tsv 가 그 자리다.
                    //
                    // **다만 후보가 하나뿐이면 받는다.** 위 목록이 무서운 것은 고르는
                    // 일이 있어서다. 하나뿐이면 틀릴 자리가 없다.
                    || (entry.writing == entry.reading
                        && (hit.entry.usableWritings.isEmpty || onlyCandidate)))
        }), !hit.entry.glosses.isEmpty else { continue }

        // **조사·조동사·계사는 건너뛴다.** 뜻이 아니라 기능이라 낱말 뜻으로 옮길 수가 없다.
        // 사전의 영어 뜻부터가 설명문이고(`の` → "indicates possessive"),
        // 그대로 넘기면 뜻 자리에 문장이 들어앉는다(`よ` → "안녕, 너").
        // 하필 빈도 최상위가 전부 이것들이라, 안 거르면 상위 N 개가 통째로 쓰레기가 된다.
        // **관용구는 옮긴다.** 앱의 `isTranslatable` 은 조사·접사·관용구를 한데 묶어
        // 빼는데, 그 잣대는 이 자리에 너무 넓다. 빼야 하는 것은 **혼자 서지 못하는 것**
        // (조사 `は`, 접사 `~的`)이지 관용구가 아니다.
        //
        // 재 보고 알았다. 빈도 1~30,000 등 안에서 한국어 뜻이 비어 있는 2,425개가
        // **거의 전부 관용구**였다 — `よろしくお願いします`(2,007위) ·
        // `申し訳ない`(1,723위) · `好きになる`(1,999위) · `その通り`(2,031위).
        // 드라마와 애니에서 매일 만나는 말들이 통째로 영어로 남아 있었다.
        //
        // 조사와 접사는 그대로 건너뛴다. 조사는 `Tools/data/function-gloss.tsv` 가
        // 손으로 적어 두었고, 접사는 낱말이 아니라 낱말의 부품이다.
        let 옮길것 = hit.entry.wordClass.isTranslatable || hit.entry.wordClass == .expression
        guard 옮길것 else {
            skipped.append(Skipped(writing: entry.writing, reading: entry.reading,
                                   wordClass: hit.entry.wordClass, english: hit.entry.glosses))
            continue
        }

        // **적어 두는 표기는 사전의 것이다.**
        //
        // 색인이 뜻을 붙일 때 쓰는 열쇠는 `사전 표기 + 읽기` 다(`DictionaryStore.build`).
        // 말뭉치가 가나로 적은 낱말을 빈도 목록의 표기 그대로(`やめる`) 적어 두면,
        // 사전은 그 낱말을 `止める` 로 싣고 있어 **열쇠가 안 맞아 영영 안 붙는다.**
        // 구워는 놓고 화면에는 영어가 뜨는 자리가 그렇게 생긴다.
        //
        // 표기 없는 낱말은 읽기가 곧 표기다 — 붙이는 쪽도 그 자리에서는
        // `읽기 + 읽기` 로 찾으므로 그대로 둔다.
        // **읽기도 사전의 것으로.** 표기와 같은 까닭이다 — 붙이는 쪽이 그것으로 찾는다.
        // 외래어는 빈도 목록의 읽기가 히라가나(`かあど`)라 그대로 적으면 안 붙는다.
        let writing = hit.entry.usableWritings.first?.text ?? hit.reading
        let key = "\(writing)\t\(hit.reading)"
        guard seen.insert(key).inserted else { continue }
        jobs.append(Job(writing: writing, reading: hit.reading,
                        english: hit.entry.glosses, wordClass: hit.entry.wordClass))
    }
    if !skipped.isEmpty { log("기능어 \(skipped.count)개는 건너뛴다 — 조사·조동사는 뜻으로 옮길 수 없다") }
    return jobs
}

func pickOnly(_ jobs: [Job], _ only: Set<String>) -> [Job] {
    only.isEmpty ? jobs : jobs.filter { only.contains($0.writing) || only.contains($0.reading) }
}

// MARK: 번역

/// ollama 로 옮긴다.
///
/// **애플 온디바이스 모델이 벽에 부딪혔다.** 한국어가 공식 지원 언어가 아니고
/// (`unsupportedLanguageOrLocale` 185건), 죽음·폭력이 든 말은 막힌다
/// (`guardrailViolation` 2,557건). 애니 대사에서 가장 궁금한 말이 정확히 그것들이다.
///
/// 견줘 보고 EXAONE 을 골랐다. 사람이 적어 둔 뜻 100개를 정답지 삼아 재니
/// **쓸 수 있는 꼴 99/100 · 뜻 일치 56/100** 이었다(qwen2.5:7b 는 79 · 30).
/// 수치보다 **틀리는 결이** 달랐다 — qwen 은 `小太り`(통통하다)를 "약간 마른체형하다"로
/// 뜻을 뒤집는데, EXAONE 은 "둥근, 살이 많다"로 말만 어색하다.
/// **어색한 것은 눈에 띄지만 틀린 것은 안 띈다.**
func translateWithOllama(_ job: Job, model: String, instructions: String,
                         temperature: Double = 0, tokens: Int = 32) async throws -> String {
    let 품사 = job.wordClass.koreanName ?? "낱말"
    let prompt = "\(job.writing)（\(job.reading)）· \(품사) · \(job.english.prefix(2).joined(separator: ", ")) →"

    var body: [String: Any] = [
        "model": model, "system": instructions, "prompt": prompt, "stream": false,
        // 사전을 만드는 일이라 **매번 같은 답이 나와야 한다.** 그래서 기본은 온도 0 이다.
        //
        // 다만 그 결정성에는 뒷면이 있다 — 한 번 틀린 것은 다시 돌려도 글자 하나까지
        // 똑같이 틀린다. 옮기다 만 것(`이웃hood`)을 다시 구우려면 온도를 올려야 한다.
        // 토큰 한도도 마찬가지다. 32 로는 설명이 붙는 낱말에서 문장이 잘려 나갔다.
        "options": ["temperature": temperature, "num_predict": tokens],
    ]
    // **생각을 끄고 답만 받는다.** Qwen3 계열은 답 앞에 `<think>` 덩어리를 먼저 뱉는데,
    // 낱말 하나를 옮기는 데 그것이 수백 토큰을 먹는다 — `num_predict` 32 안에서는
    // 생각만 하다 끝나 답이 한 글자도 안 나온다. 생각을 지원하지 않는 모델은
    // 이 값을 그냥 무시한다(재 봤다).
    if model.contains("qwen3") { body["think"] = false }
    var request = URLRequest(url: URL(string: "http://localhost:11434/api/generate")!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    request.timeoutInterval = 120

    let (data, _) = try await URLSession.shared.data(for: request)
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let text = json["response"] as? String
    else { throw Failure("ollama 응답을 읽지 못했다") }

    // 생각 덩어리가 딸려 오면 걷어낸다. 끄고 물었어도 모델이 본문에 적어 보내는 일이 있다.
    var body부분 = text
    if let close = body부분.range(of: "</think>") { body부분 = String(body부분[close.upperBound...]) }

    // 모델이 줄을 여럿 뱉으면 첫 줄만 쓴다. 뒷줄은 대개 자기 설명이다.
    // **빈 줄은 건너뛴다** — 생각을 걷어낸 자리에 줄바꿈이 남아 첫 줄이 빈 칸이 된다.
    let 첫줄 = body부분.split(separator: "\n")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty } ?? ""

    // **물음을 되받아 적은 것은 화살표 뒤만 취한다.**
    //
    // 프롬프트가 `표기（읽기）· 품사 · 영어뜻 →` 이라 이어서 답만 적으면 되는데,
    // 모델이 그 줄을 통째로 다시 적고 그 뒤에 답을 붙이는 일이 있다
    // (`岐阜（ぎふ）· 명사 · Gifu → 기후`). 그대로 두면 일본어가 섞였다는 이유로
    // 색인에 실릴 때 통째로 버려진다 — qwen3:8b 를 1,236개로 재니 못 쓰는 꼴 80개 중
    // **41개가 이것**이었다. 화살표는 우리가 준 글자이고 한국어 뜻에는 올 일이 없다.
    guard let 화살표 = 첫줄.range(of: "→", options: .backwards) else { return 첫줄 }
    let 뒤 = 첫줄[화살표.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
    // 화살표로 끝난 것(답을 안 적고 물음만 되뱉은 것)은 앞을 살려 봐야 소용없다.
    return 뒤.isEmpty ? "" : 뒤
}

#if canImport(FoundationModels)
@available(macOS 26.0, *)
/// **뜻을 배열로 받는다.** 한 칸짜리 문자열로 받으면 그 안에 무엇이든 넣을 수 있어서
/// "무기를 가지고 있는 것과 같이 목표로 삼다– 어떤 것을..." 같은 것이 통째로 들어왔다.
/// 칸을 나누고 개수를 못 박으면 형식이 프롬프트가 아니라 **구조**로 강제된다.
@Generable
struct KoreanGloss {
    @Guide(description: """
        한국어 뜻 하나. 사전에 실릴 만한 짧은 말이다.
        낱말이나 짧은 구로 적고 설명하지 않는다. 여덟 자를 넘기지 않는다.
        동사와 형용사는 "-다"로 끝나는 기본형으로 적는다.
        서로 다른 뜻만 담는다. 같은 말을 두 번 적지 않는다.
        """, .count(1...2))
    var meanings: [String]
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
    // 칸마다 다듬고, 같은 말은 한 번만 남긴다. 합치는 것은 마지막에 한 번.
    var seen: [String] = []
    for meaning in response.content.meanings {
        let text = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !seen.contains(text) else { continue }
        seen.append(text)
    }
    return seen.joined(separator: ", ")
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
// **앱이 싣는 빈도 목록으로 굽는다.** 무엇을 구울지는 이 목록의 차례가 정하는데,
// 한때 기본값이 JPDB 였다. 그것으로 3만 등까지 구워 놓고도 앱 기준으로는 구멍이
// 1,232개 남아 있었다 — 두 목록이 고르는 낱말이 다르다(JESC 3만 등 대상 9,501개 중
// JPDB 3만 등에 없는 것이 2,131개). 측정기가 같은 자리에서 어긋났던 것과 같은 병이다.
let frequencyPath = value("--freq") ?? "MworagoApp/Resources/jesc_freq.tsv"
let outputPath = value("--out") ?? "Tools/data/korean-gloss.tsv"
let limit = value("--limit").flatMap(Int.init) ?? 20000
// 모델에 무엇이 넘어가는지만 보고 끝낸다. 결과가 이상할 때
// 사전에서 잘못 골랐는지 모델이 잘못 옮겼는지부터 갈라야 하기 때문이다.
let dryRun = arguments.contains("--dry-run")
// 표기 몇 개만 골라 다시 굽는다. 프롬프트나 스키마를 손볼 때
// 정확히 같은 낱말로 전후를 견주려면 이것이 있어야 한다.
let only = Set((value("--only") ?? "").split(separator: ",").map(String.init))
// 건너뛴 기능어만 찍는다. 번역은 안 하지만 화면에는 나오는 낱말들이라,
// 뜻 자리를 무엇으로 채울지 정하려면 무엇이 자주 나오는지부터 알아야 한다.
let listSkipped = arguments.contains("--skipped")
// ollama 로 옮긴다. 없으면 애플 온디바이스 모델을 쓴다.
let ollamaModel = value("--ollama")
// **다시 구울 때만 건드린다.** 기본값은 처음 구울 때 쓴 것 그대로다.
let temperature = value("--temp").flatMap(Double.init) ?? 0
let tokens = value("--tokens").flatMap(Int.init) ?? 32
// 빈도 순위 상한. 대상 개수(`--limit`)와 다르다 — 개수로만 끊으면 조건에 걸려 빠진
// 낱말들 때문에 훨씬 아래까지 내려간다(2만 개를 채우느라 45,266위까지 갔다).
let maxRank = value("--max-rank").flatMap(Int.init)

// **뜻 자리에 소리가 들어앉은 것을 찾는다.**
//
// 모델이 옮기지 못하면 옮기는 대신 **음차**를 적어 놓는 일이 있다(`霞` → "카스미").
// 뜻이 없는 것은 화면에서 티가 나지만 이것은 안 난다 — 한국어 글자로 채워져 있다.
//
// 외래어는 음차가 곧 뜻이다(`ラーメン` → 라멘). 그래서 **가나로만 쓰는 낱말은 묻지 않고**,
// 한자 표기가 있는 낱말만 본다.
if arguments.contains("--audit") {
    var glosses: [String: String] = [:]
    for name in ["korean-gloss", "guardrail-gloss", "corrected-gloss", "function-gloss"] {
        guard let text = try? String(contentsOfFile: "Tools/data/\(name).tsv", encoding: .utf8) else { continue }
        for line in text.split(separator: "\n") where !line.hasPrefix("#") {
            let columns = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard columns.count >= 3 else { continue }
            glosses["\(columns[0])\t\(columns[1])"] = String(columns[2])
        }
    }
    // **한자어는 소리와 뜻이 우연히 같다.** `要素`(ようそ)의 한국어 뜻 "요소"는 음차와
    // 같은 글자지만 그것이 정말 뜻이다. 한국 독음표가 그 둘을 갈라 준다 —
    // 뜻이 **독음과도 같으면** 한자어라서 같은 것이고, 독음과 다르면 옮기다 만 것이다.
    let hanja = HanjaReading(contentsOfFile: "MworagoApp/Resources/hanja-reading.tsv")
    var 걸린것 = 0
    for (key, gloss) in glosses.sorted(by: { $0.key < $1.key }) {
        let parts = key.split(separator: "\t", omittingEmptySubsequences: false)
        guard parts.count == 2 else { continue }
        let (writing, reading) = (String(parts[0]), String(parts[1]))
        // 한자가 없으면 음차가 뜻일 수 있다 — 외래어와 가나 낱말은 건너뛴다.
        guard writing.unicodeScalars.contains(where: { (0x4E00...0x9FFF).contains($0.value) })
        else { continue }
        let 소리 = KanaToHangul.transliterate(reading)
        guard !소리.isEmpty else { continue }
        // 뜻이 소리 그대로이거나, 뜻의 첫 갈래가 소리 그대로인 것
        let 첫뜻 = gloss.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? gloss
        guard gloss == 소리 || 첫뜻 == 소리 else { continue }
        let 독음 = hanja.reading(of: writing)
        if 독음 == 소리 || 독음 == 첫뜻 { continue }   // 한자어다
        걸린것 += 1
        print("\(writing)\t\(reading)\t\(gloss)\t← 소리 \(소리) · 독음 \(독음 ?? "—")")
    }
    log("뜻 자리에 소리가 들어앉은 것 \(걸린것)개 / 뜻 \(glosses.count)개")
    exit(0)
}

// 이미 번역한 것은 건너뛴다 — 몇 시간짜리 작업이라 중단은 예외가 아니라 일상이다.
var done: Set<String> = []
if let existing = try? String(contentsOfFile: outputPath, encoding: .utf8) {
    for line in existing.split(separator: "\n") where !line.hasPrefix("#") {
        let columns = line.split(separator: "\t", omittingEmptySubsequences: false)
        if columns.count >= 2 { done.insert("\(columns[0])\t\(columns[1])") }
    }
    log("이미 끝난 것 \(done.count)개 — 건너뛴다")
}

// **무엇으로 고르는지 먼저 찍는다.** 대상 집합을 정하는 것이 빈도 목록과 순위 상한인데,
// 그것을 안 남기면 나중에 "왜 이 낱말이 안 구워졌나"를 되짚을 수가 없다.
log("빈도 목록 \(frequencyPath) · 순위 상한 \(maxRank.map(String.init) ?? "없음") · 개수 상한 \(limit)")
var skipped: [Skipped] = []
let jobs = pickOnly(try loadJobs(indexPath: indexPath, frequencyPath: frequencyPath, limit: limit,
                                 maxRank: maxRank, skipped: &skipped), only)

if listSkipped {
    for word in skipped {
        print("\(word.writing)\t\(word.reading)\t\(word.wordClass.rawValue)\t\(word.english.joined(separator: ", "))")
    }
    exit(0)
}

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

/// ollama 에 줄 지시문.
///
/// **사람이 적은 뜻 100개로 채점해 다듬은 것이다.** 처음 것은 중국어가 새어
/// (`狙う → "목표를主观하다"`) 21%가 꼴부터 못 썼는데, "한 글자도 섞지 않는다"를
/// 못 박고 보기를 늘리자 1%로 떨어졌다.
let ollamaInstructions = """
    너는 일본어-한국어 사전 편집자다. 일본어 낱말의 한국어 뜻만 적는다.

    반드시 지킬 것:
    - 오직 한국어로만 쓴다. 한자·일본어·영어·중국어를 한 글자도 섞지 않는다.
    - 뜻만 적는다. 설명·인사·군더더기를 붙이지 않는다.
    - 뜻은 하나나 둘. 쉼표로 나눈다. 셋 이상 적지 않는다.
    - 각 뜻은 12자 이내.
    - 동사는 "-다", 형용사는 "-다"로 끝낸다. 명사는 명사로 적는다.
    - 영어 뜻을 그대로 옮기지 말고, 한국어에서 실제로 쓰는 말을 고른다.
    - 모르면 억지로 지어내지 말고 영어 뜻에 가장 가까운 한국어 한 낱말만 적는다.

    보기:
    約束（やくそく）· 명사 · promise, agreement → 약속
    思う（おもう）· 동사 · to think, to consider → 생각하다
    狙う（ねらう）· 동사 · to aim at, to target → 노리다
    起訴（きそ）· 명사 · prosecution, indictment → 기소
    不機嫌（ふきげん）· 형용사 · bad mood, sullen → 언짢다
    発電（はつでん）· 명사 · generation of electricity → 발전
    """

// **지시문을 파일로 갈아 끼울 수 있다.** 모델을 바꾸면 잘 듣는 말도 달라지는데,
// 그때마다 다시 빌드해서는 같은 낱말로 전후를 견줄 수가 없다.
let instructions = (value("--instructions").flatMap { try? String(contentsOfFile: $0, encoding: .utf8) })
    ?? ollamaInstructions

if let ollamaModel {
    log("ollama · \(ollamaModel)"
        + (value("--instructions").map { " · 지시문 \($0)" } ?? ""))
    if !FileManager.default.fileExists(atPath: outputPath) {
        // **무엇으로 구웠는지 파일에 적어 둔다.** 대상 집합은 `--limit` 이 정하는데,
        // 그 값을 어디에도 남기지 않아 다시 구울 때 같은 집합을 만들지 못했다.
        try ("# 표기\t읽기\t한국어뜻\n"
             + "# ollama \(ollamaModel) · limit=\(limit) · temp=\(temperature) · tokens=\(tokens)\n")
            .write(toFile: outputPath, atomically: true, encoding: .utf8)
    }
    let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: outputPath))
    try handle.seekToEnd()
    defer { try? handle.close() }

    let start = Date()
    var count = 0
    for job in remaining {
        do {
            let korean = try await translateWithOllama(job, model: ollamaModel,
                                                       instructions: instructions,
                                                       temperature: temperature, tokens: tokens)
            guard !korean.isEmpty else { continue }
            try handle.write(contentsOf: Data("\(job.writing)\t\(job.reading)\t\(korean)\n".utf8))
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
        try ("# 표기\t읽기\t한국어뜻\n"
             + "# 애플 온디바이스 모델 · limit=\(limit)\n")
            .write(toFile: outputPath, atomically: true, encoding: .utf8)
    }
    let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: outputPath))
    try handle.seekToEnd()
    defer { try? handle.close() }

    // 규칙만 늘어놓는 것보다 **보기 몇 개**가 형식을 더 잘 붙든다.
    // 특히 "설명하지 말라"는 지시는 잘 지켜지지 않는데, 짧은 답을 보여 주면 따라온다.
    let instructions = """
        너는 일본어-한국어 사전을 만든다. 낱말의 뜻만 적는다.

        약속:
        - 사전에 실릴 만한 짧은 말로 적는다. 문장으로 설명하지 않는다.
        - 품사를 지킨다. 동사와 형용사는 "-다"로 끝나는 기본형이다.
        - 한국어로만 적는다. 한자·가나·로마자를 섞지 않는다.
        - 뜻이 겹치면 하나만 적는다.

        보기:
        約束（やくそく）· 명사 · promise, agreement → 약속
        思う（おもう）· 동사 · to think, to consider → 생각하다
        狙う（ねらう）· 동사 · to aim at, to target → 노리다
        不機嫌（ふきげん）· 형용사 · bad mood, sullen → 언짢은
        宿命（しゅくめい）· 명사 · fate, destiny → 숙명
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
