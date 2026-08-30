import Testing
import Foundation
@testable import MworagoCore

/// 품사는 화면보다 **번역**을 위해 필요하다.
///
/// 영어 뜻만 넘겨 주면 `思う`(to think)가 "생각"으로 온다 — 동사가 명사가 되어 돌아온다.
/// 그리고 빈도 최상위는 전부 조사·조동사인데, 그것들은 뜻이 아니라 기능이라
/// 낱말 뜻으로 옮기려 들면 설명문이 나온다(`よ` → "안녕, 너").
/// 둘 다 사전이 이미 알고 있는 것을 안 읽어서 생긴 일이다.
@Suite("품사")
struct WordClassTests {

    static let sample = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE JMdict [
    <!ENTITY prt "particle">
    <!ENTITY v5u "Godan verb with 'u' ending">
    <!ENTITY vt "transitive verb">
    <!ENTITY adj-na "adjectival nouns or quasi-adjectives">
    <!ENTITY n "noun">
    <!ENTITY cop "copula">
    <!ENTITY adv "adverb">
    <!ENTITY exp "expressions (phrases, clauses, etc.)">
    <!ENTITY suf "suffix">
    <!ENTITY pref "prefix">
    <!ENTITY int "interjection (kandoushi)">
    <!ENTITY vs-i "suru verb - irregular">
    <!ENTITY vi "intransitive verb">
    <!ENTITY v1 "Ichidan verb">
    <!ENTITY vs "noun or participle which takes the aux. verb suru">
    <!ENTITY aux-v "auxiliary verb">
    <!ENTITY conj "conjunction">
    ]>
    <JMdict>
    <entry>
    <r_ele><reb>の</reb></r_ele>
    <sense><pos>&prt;</pos><gloss>indicates possessive</gloss></sense>
    </entry>
    <entry>
    <k_ele><keb>思う</keb></k_ele>
    <r_ele><reb>おもう</reb></r_ele>
    <sense><pos>&v5u;</pos><pos>&vt;</pos><gloss>to think</gloss><gloss>to consider</gloss></sense>
    <sense><pos>&v5u;</pos><pos>&vt;</pos><gloss>to judge</gloss></sense>
    </entry>
    <entry>
    <k_ele><keb>大丈夫</keb></k_ele>
    <r_ele><reb>だいじょうぶ</reb></r_ele>
    <sense><pos>&adj-na;</pos><pos>&n;</pos><gloss>safe</gloss></sense>
    </entry>
    <entry>
    <r_ele><reb>だ</reb></r_ele>
    <sense><pos>&cop;</pos><gloss>be</gloss></sense>
    </entry>
    <entry>
    <k_ele><keb>元</keb></k_ele>
    <r_ele><reb>もと</reb></r_ele>
    <sense><pos>&n;</pos><gloss>origin</gloss></sense>
    </entry>
    <entry>
    <r_ele><reb>とても</reb></r_ele>
    <sense><pos>&adv;</pos><gloss>very</gloss></sense>
    </entry>
    <entry>
    <r_ele><reb>だろう</reb></r_ele>
    <sense><pos>&exp;</pos><gloss>seems</gloss><gloss>I think</gloss></sense>
    </entry>
    <entry>
    <r_ele><reb>さん</reb></r_ele>
    <sense><pos>&suf;</pos><gloss>Mr</gloss><gloss>Mrs</gloss></sense>
    </entry>
    <entry>
    <r_ele><reb>お</reb></r_ele>
    <sense><pos>&pref;</pos><gloss>honorific prefix</gloss></sense>
    </entry>
    <entry>
    <r_ele><reb>ありがとう</reb></r_ele>
    <sense><pos>&int;</pos><gloss>thank you</gloss></sense>
    </entry>
    <entry>
    <r_ele><reb>する</reb></r_ele>
    <sense><pos>&vs-i;</pos><pos>&vi;</pos><pos>&vt;</pos><pos>&suf;</pos><pos>&aux-v;</pos>
    <gloss>to do</gloss><gloss>to carry out</gloss></sense>
    </entry>
    <entry>
    <k_ele><keb>見る</keb></k_ele>
    <r_ele><reb>みる</reb></r_ele>
    <sense><pos>&v1;</pos><pos>&vt;</pos><pos>&aux-v;</pos><gloss>to see</gloss></sense>
    </entry>
    <entry>
    <k_ele><keb>勉強</keb></k_ele>
    <r_ele><reb>べんきょう</reb></r_ele>
    <sense><pos>&n;</pos><pos>&vs;</pos><gloss>study</gloss></sense>
    </entry>
    <entry>
    <r_ele><reb>ちゃう</reb></r_ele>
    <sense><pos>&aux-v;</pos><gloss>to do completely</gloss></sense>
    </entry>
    <entry>
    <r_ele><reb>も</reb></r_ele>
    <sense><pos>&prt;</pos><pos>&adv;</pos><gloss>too</gloss><gloss>also</gloss></sense>
    </entry>
    <entry>
    <r_ele><reb>と</reb></r_ele>
    <sense><pos>&prt;</pos><pos>&conj;</pos><pos>&n;</pos><gloss>if</gloss><gloss>when</gloss></sense>
    </entry>
    </JMdict>
    """

    static func 항목(_ 읽기: String) throws -> DictEntry {
        let entries = try JMDictParser.parse(xml: sample)
        return try #require(entries.first { $0.readings.contains { $0.text == 읽기 } })
    }

    @Test("품사 태그를 뽑는다")
    func 파싱() throws {
        #expect(try Self.항목("おもう").partsOfSpeech == ["v5u", "vt"])
        #expect(try Self.항목("の").partsOfSpeech == ["prt"])
    }

    @Test("같은 태그가 뜻갈래마다 되풀이돼도 한 번만 담는다")
    func 중복제거() throws {
        // 思う 는 sense 가 둘이고 둘 다 v5u·vt 다. 그대로 쌓으면 네 개가 된다.
        #expect(try Self.항목("おもう").partsOfSpeech.count == 2)
    }

    @Test("큰 갈래로 묶는다")
    func 분류() throws {
        #expect(try Self.항목("おもう").wordClass == .verb)
        #expect(try Self.항목("だいじょうぶ").wordClass == .adjective)
        #expect(try Self.항목("もと").wordClass == .noun)
        #expect(try Self.항목("とても").wordClass == .adverb)
    }

    @Test("조사와 계사는 기능어다")
    func 기능어() throws {
        #expect(try Self.항목("の").wordClass == .function)
        #expect(try Self.항목("だ").wordClass == .function)
        // 번역 대상에서 빼는 판단은 이 한 줄로 한다.
        #expect(try Self.항목("の").wordClass.isTranslatable == false)
        #expect(try Self.항목("おもう").wordClass.isTranslatable)
    }

    @Test("형용동사는 명사 태그를 겸해도 형용사로 본다")
    func 겸업() throws {
        // 大丈夫 는 adj-na 와 n 을 함께 단다. 먼저 쓰인 쪽이 그 낱말의 얼굴이다.
        #expect(try Self.항목("だいじょうぶ").partsOfSpeech == ["adj-na", "n"])
        #expect(try Self.항목("だいじょうぶ").wordClass == .adjective)
    }

    @Test("품사가 없는 항목도 죽지 않는다")
    func 태그없음() throws {
        let entry = DictEntry(readings: [DictForm(text: "ゆき", priority: 0)], writings: [], glosses: ["snow"])
        #expect(entry.partsOfSpeech.isEmpty)
        #expect(entry.wordClass == .other)
        // 모르는 것을 기능어로 몰면 멀쩡한 낱말이 통째로 번역에서 빠진다.
        #expect(entry.wordClass.isTranslatable)
    }

    @Test("관용구와 접사는 낱말 뜻으로 옮기지 않는다")
    func 옮길수없는것() throws {
        // だろう(exp)·さん(suf)·お(pref) 는 사전에 뜻이 달려 있어도 그 뜻이 낱말이 아니다.
        // 실측에서 각각 "보인다", "시스터, 브레이어", "오!" 가 나왔다.
        #expect(try Self.항목("だろう").wordClass == .expression)
        #expect(try Self.항목("さん").wordClass == .affix)
        #expect(try Self.항목("お").wordClass == .affix)
        #expect(try Self.항목("だろう").wordClass.isTranslatable == false)
        #expect(try Self.항목("さん").wordClass.isTranslatable == false)
    }

    @Test("감탄사는 옮긴다 — 그것은 뜻이 있는 낱말이다")
    func 감탄사() throws {
        // ありがとう 를 접사와 한데 묶어 버리면 정작 애니에서 가장 많이 들리는 말이 빠진다.
        #expect(try Self.항목("ありがとう").wordClass.isTranslatable)
    }

    @Test("보조동사로도 쓰이는 동사는 동사다")
    func 겸업동사() throws {
        // する 의 태그는 vs-i·vi·vt·suf·aux-v 다. 뒤에 붙은 suf·aux-v 때문에 기능어로
        // 몰면, 애니에서 가장 흔한 동사들이 통째로 뜻을 잃는다 —
        // する·見る·行く·来る·いる·くれる·やる·しまう 가 전부 그랬다.
        // **혼자 서지 못하는 것과 혼자도 서는 것은 다르다.**
        #expect(try Self.항목("する").wordClass == .verb)
        #expect(try Self.항목("みる").wordClass == .verb)
        #expect(try Self.항목("する").wordClass.isTranslatable)
    }

    @Test("보조 노릇만 하는 것은 기능어로 남는다")
    func 순수보조() throws {
        // ちゃう 는 aux-v 뿐이다. 혼자서는 뜻이 서지 않는다.
        #expect(try Self.항목("ちゃう").wordClass == .function)
    }

    @Test("する 를 붙여 쓰는 명사는 명사다")
    func 명사겸동사() throws {
        // 勉強 은 n·vs 다. vs 는 "する 가 붙는 낱말"이라는 표지지 동사 태그가 아니다.
        // 먼저 쓰인 n 이 이 낱말의 얼굴이다.
        #expect(try Self.항목("べんきょう").wordClass == .noun)
    }

    @Test("조사가 부사나 명사를 겸해도 조사다")
    func 조사겸업() throws {
        // も 는 prt·adv, と 는 prt·conj·n 이다. 실질 품사를 먼저 보게 하면
        // 이것들이 부사와 명사로 새어 나가 번역 대상이 된다 —
        // 실제로 も 가 "도움’를 줄’것—" 로, と 가 "만약, 언제" 로 왔다.
        //
        // **JMdict 는 주된 품사를 먼저 적는다.** する 는 vs-i 가 먼저고 も 는 prt 가 먼저다.
        // 어느 쪽을 우선할지 정할 것이 아니라 사전이 적은 순서를 그대로 따르면 둘 다 맞는다.
        #expect(try Self.항목("も").wordClass == .function)
        #expect(try Self.항목("と").wordClass == .function)
        #expect(try Self.항목("する").wordClass == .verb)
    }
}
