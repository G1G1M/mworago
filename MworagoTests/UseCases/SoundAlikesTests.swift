import Testing
import Foundation
@testable import MworagoDomain
@testable import MworagoUseCases

/// 한 글자만 다르게 들었다면 닿았을 낱말.
///
/// 사전은 가짜로 세운다 — 여기서 보는 것은 **언제 곁들이고 언제 입을 다무는가**이고,
/// 실제 사전 위의 성적은 `SpikeRunner --sound-alike` 가 잰다.
@Suite("비슷한 소리")
struct SoundAlikesTests {

    static func 결과(_ 표기: String, _ 읽기: String, score: Double, 되돌림: String? = nil) -> SearchResult {
        let entry = DictEntry(readings: [DictForm(text: 읽기, priority: 0)],
                              writings: 표기 == 읽기 ? [] : [DictForm(text: 표기, priority: 0)],
                              glosses: [표기])
        return SearchResult(entry: entry, reading: 읽기, matchedKana: 읽기,
                            deinflection: 되돌림, score: score)
    }

    /// 한글 → 1위 하나만 아는 가짜 찾기.
    static func 찾기(_ 표: [String: SearchResult]) -> (String) -> [SearchResult] {
        { 표[$0].map { [$0] } ?? [] }
    }

    @Test("자모 셋으로 세운 음절은 분해한 것과 같은 글자로 돌아온다")
    func 조립() throws {
        for 글자 in "갓코아타마뷁힣가" {
            let 음절 = try #require(HangulSyllable(글자))
            let 다시 = try #require(HangulSyllable(initial: 음절.initial, medial: 음절.medial, final: 음절.final))
            #expect(다시.character == 글자)
        }
        #expect(HangulSyllable(initial: "a", medial: "ㅏ", final: nil) == nil)
    }

    @Test("탁음은 거센소리를 예사소리로만 바꾼다 — ㅅ 은 건드리지 않는다")
    func 탁음이웃() {
        #expect(SoundAlikes.neighbors(of: "캇코", voicingOnly: true).map(\.hangul) == ["갓코", "캇고"])
        // ㅈ 은 ち 까지 열어 엉뚱한 낱말이 걸렸다(`코소` → こと).
        #expect(SoundAlikes.neighbors(of: "코소", voicingOnly: true).map(\.hangul) == ["고소"])
        // 예사소리는 이미 청음과 탁음을 다 연다. 바꿀 것이 없다.
        #expect(SoundAlikes.neighbors(of: "가다", voicingOnly: true).isEmpty)
    }

    @Test("찾은 조각에는 고친 쪽이 여유만큼 더 흔할 때만 곁들인다")
    func 더흔할때만() {
        let segment = Segment(hangul: "캇코", results: [Self.결과("格好", "かっこう", score: 50)])
        let 흔함 = SoundAlikes.suggestions(for: segment, lookup: Self.찾기(["갓코": Self.결과("学校", "がっこう", score: 80)]))
        #expect(흔함.map(\.hangul) == ["갓코"])
        #expect(흔함.first?.result.headword == "学校")
        #expect(흔함.first?.change == .voicing)

        // 1위보다 흔하긴 하지만 여유(10)를 못 넘는다 — `카와` 의 側(차이 3)이 이랬다.
        let 비슷함 = SoundAlikes.suggestions(for: segment, lookup: Self.찾기(["갓코": Self.결과("学校", "がっこう", score: 59)]))
        #expect(비슷함.isEmpty)
    }

    @Test("한 글자 조각과 통째 후보는 고치지 않는다")
    func 고치지않는조각() {
        let 표 = Self.찾기(["즈": Self.결과("ず", "ず", score: 99), "갓코": Self.결과("学校", "がっこう", score: 99)])
        let 한글자 = Segment(hangul: "스", results: [Self.결과("す", "す", score: 10)])
        #expect(SoundAlikes.suggestions(for: 한글자, lookup: 표).isEmpty)
        let 통째 = Segment(hangul: "캇코", results: [Self.결과("格好", "かっこう", score: 10)], isWhole: true)
        #expect(SoundAlikes.suggestions(for: 통째, lookup: 표).isEmpty)
    }

    @Test("1위가 사전에 그대로 실린 낱말이면 활용을 되돌려 맞은 쪽은 내지 않는다")
    func 되돌린것() {
        let segment = Segment(hangul: "캇타", results: [Self.결과("勝った", "かった", score: 40)])
        let 표 = Self.찾기(["갓타": Self.결과("合う", "あう", score: 90, 되돌림: "과거형")])
        #expect(SoundAlikes.suggestions(for: segment, lookup: 표).isEmpty)
    }

    @Test("못 찾은 조각에는 한 글자 바꾼 소리를 흔한 순으로 낸다")
    func 못찾은조각() {
        let segment = Segment(hangul: "아디가", results: [])
        let 표 = Self.찾기([
            "아리가": Self.결과("有りが", "ありが", score: 30),
            "안디가": Self.결과("案出が", "あんでが", score: 70),
        ])
        let found = SoundAlikes.suggestions(for: segment, lookup: 표)
        #expect(found.map(\.hangul) == ["안디가", "아리가"])
        #expect(found.map(\.change) == [.nasalAdded, .liquid])
    }

    @Test("입력이 엉뚱하게 갈렸으면 통째로 한 글자 고친 낱말을 낸다")
    func 통째() {
        let 갈린것 = [
            Segment(hangul: "아디", results: [Self.결과("あ", "あ", score: 10)]),
            Segment(hangul: "가토", results: [Self.결과("が", "が", score: 10)]),
        ]
        let 표 = Self.찾기(["아리가토": Self.결과("有難う", "ありがとう", score: 90)])
        let 고침 = SoundAlikes.wholeSuggestion(for: "아디가토", segments: 갈린것, lookup: 표)
        #expect(고침?.hangul == "아리가토")
        #expect(고침?.change == .liquid)

        // 이미 한 낱말로 찾았으면 묻지 않는다.
        let 한조각 = [Segment(hangul: "아디가토", results: [Self.결과("x", "x", score: 1)])]
        #expect(SoundAlikes.wholeSuggestion(for: "아디가토", segments: 한조각, lookup: 표) == nil)
        // 통째 후보가 이미 섰어도 묻지 않는다.
        let 통째섬 = [Segment(hangul: "아디가토", results: [Self.결과("x", "x", score: 1)], isWhole: true)] + 갈린것
        #expect(SoundAlikes.wholeSuggestion(for: "아디가토", segments: 통째섬, lookup: 표) == nil)
    }

    @Test("고친 소리로 바꿀 때 사람이 띄어 쓴 자리는 남는다")
    func 바꾸기() {
        let segments = [
            Segment(hangul: "아타마가이타이", results: [], isWhole: true),
            Segment(hangul: "아타마", results: []),
            Segment(hangul: "가", results: []),
            Segment(hangul: "이타이", results: []),
        ]
        #expect(SoundAlikes.replacing("아타마 가이타이", segments: segments, at: 2, with: "이다이") == "아타마 가이다이")
        #expect(SoundAlikes.replacing("아타마 가이타이", segments: segments, at: 0, with: "아다마") == "아다마 가이타이")
        // 없는 자리는 그대로 돌려준다.
        #expect(SoundAlikes.replacing("아타마", segments: segments, at: 9, with: "x") == "아타마")
    }
}
