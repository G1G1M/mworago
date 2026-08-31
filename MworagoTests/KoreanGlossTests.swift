import Testing
import Foundation
@testable import MworagoCore

/// 모델이 옮겨 준 한국어 뜻을 화면에 올릴 만한 것으로 다듬는다.
///
/// 아래 사례는 전부 실제로 나온 것이다. 임계값도 손으로 정하지 않았다 —
/// 766건을 재어 보니 조각 길이가 중앙 3자, 95%가 8자 이하인데 최대는 43자였다.
/// 꼬리가 뚜렷하게 갈려서 12자를 넘으면 뜻이 아니라 설명으로 본다(1352개 중 22개).
@Suite("한국어 뜻 다듬기")
struct KoreanGlossTests {

    @Test("구분자를 쉼표로 통일한다")
    func 구분자() {
        // 모델이 ; 와 , 를 섞어 쓴다 — 485번 대 101번이었다.
        #expect(KoreanGloss.tidy("있다; 존재하다") == "있다, 존재하다")
        #expect(KoreanGloss.tidy("생각하다 · 고려하다") == "생각하다, 고려하다")
    }

    @Test("같은 뜻을 두 번 적은 것은 한 번만 남긴다")
    func 중복() {
        // 766건 중 86건이 그랬다. 영어 뜻 둘이 비슷한 말이면 같은 한국어로 옮겨진다.
        #expect(KoreanGloss.tidy("식사, 식사") == "식사")
        #expect(KoreanGloss.tidy("충분하다; 충분하다") == "충분하다")
        #expect(KoreanGloss.tidy("말하다, 말하다") == "말하다")
    }

    @Test("설명문은 뜻이 아니다")
    func 설명문() {
        // 狙う 가 이렇게 왔다. 뜻 자리에 넣을 수 없는 길이다.
        #expect(KoreanGloss.tidy("무기를 가지고 있는 것과 같이 목표로 삼다") == nil)
        // 조각 하나만 길면 그것만 버리고 나머지는 살린다.
        #expect(KoreanGloss.tidy("포기하다, 기다릴 수 없어서 단념하고 물러나다") == "포기하다")
    }

    @Test("한글이 없으면 옮기지 못한 것이다")
    func 번역실패() {
        // "(not) particularly" 처럼 영어가 그대로 돌아온 것들이 있었다.
        // 뜻이 없는 편이 낫다 — 영어 뜻이 그 자리를 대신한다.
        #expect(KoreanGloss.tidy("(not) particularly") == nil)
        #expect(KoreanGloss.tidy("mono") == nil)
    }

    @Test("이상한 기호를 걷어낸다")
    func 기호() {
        // ´ 가 13번, ’ 가 3번, ° 와 ¸ 가 한 번씩 나왔다. 무엇을 뜻하는지 알 수 없다.
        #expect(KoreanGloss.tidy("행동´실행") == "행동, 실행")
        #expect(KoreanGloss.tidy("반대°") == "반대")
        #expect(KoreanGloss.tidy("지금’, 곧’") == "지금, 곧")
    }

    @Test("둘까지만 싣는다")
    func 개수() {
        // 화면에 보이는 것은 앞의 한둘이다. 사전 자체가 뜻을 둘까지만 담는다.
        #expect(KoreanGloss.tidy("하나, 둘, 셋, 넷") == "하나, 둘")
    }

    @Test("빈 것과 공백만 있는 것은 없는 것이다")
    func 빈것() {
        #expect(KoreanGloss.tidy("") == nil)
        #expect(KoreanGloss.tidy("   ") == nil)
        #expect(KoreanGloss.tidy(", ;") == nil)
    }

    @Test("괄호 안은 뜻이 아니라 부연이다")
    func 괄호() {
        // "이, 마지막 (몇 년, 등)" 은 영어 뜻 "this, last (couple of years, etc.)" 를
        // 그대로 옮긴 것이다. 쉼표로 쪼개면 "마지막 (몇 년" 같은 깨진 조각이 남으므로
        // 쪼개기 전에 괄호째 걷어낸다.
        #expect(KoreanGloss.tidy("이, 마지막 (몇 년, 등)") == "이, 마지막")
        #expect(KoreanGloss.tidy("오! (미소 지으며 느끼는 미묘한 놀라움)") == "오!")
        // 닫는 괄호가 없으면 거기서부터 끝까지가 부연이다.
        #expect(KoreanGloss.tidy("놀라다 (뜻밖의 일을") == "놀라다")
    }

    @Test("대시와 따옴표도 갈라 주는 자리다")
    func 대시() {
        #expect(KoreanGloss.tidy("수면—죽음") == "수면, 죽음")
        #expect(KoreanGloss.tidy("잠깐만 봐봐——") == "잠깐만 봐봐")
        #expect(KoreanGloss.tidy("실재”") == "실재")
    }

    @Test("한 조각 안에 딴 나라 글자가 섞이면 그 조각을 버린다")
    func 섞인조각() {
        // 2,225건 중 29건이 그랬다. 조각 사이에 섞인 것은 이미 갈려서 걸러진다
        // ("남기는; undone" → "남기는"). 남는 것은 한 조각 안에서 섞인 경우다.
        #expect(KoreanGloss.tidy("만족신 contentment") == nil)
        #expect(KoreanGloss.tidy("네ighborhood") == nil)
        // 성한 조각은 살린다 — 버리는 것은 섞인 그 조각뿐이다.
        #expect(KoreanGloss.tidy("인형, 인형 Puppet") == "인형")
        #expect(KoreanGloss.tidy("간단하다 plain하다") == nil)
        // 일본어가 한국어 뜻 자리에 남아서는 안 된다.
        #expect(KoreanGloss.tidy("모두, みんな") == "모두")
    }

    @Test("조사의 자리 표시는 깎지 않는다")
    func 조사자리() {
        // 기능어는 뜻이 아니라 자리를 적는다(`~의`처럼 붙여 쓰는 꼴 그대로).
        // `~` 를 구분자로 두면 그 표가 통째로 깎인다.
        #expect(KoreanGloss.tidy("~의, ~것") == "~의, ~것")
        #expect(KoreanGloss.tidy("~하지 마, ~구나") == "~하지 마, ~구나")
    }

    @Test("문장 끝의 마침표는 뗀다")
    func 마침표() {
        // 27,814조각 중 902개(3.2%)가 마침표로 끝났다. "크다." 는 마침표만 떼면
        // 멀쩡한 뜻이 되는데, 붙어 있으면 화면에서 낱말이 아니라 문장으로 읽힌다.
        #expect(KoreanGloss.tidy("크다.") == "크다")
        #expect(KoreanGloss.tidy("숨을 쉬어라., 쉬었다.") == "숨을 쉬어라, 쉬었다")
        // 말줄임표도 같다.
        #expect(KoreanGloss.tidy("그렇구나...") == "그렇구나")
        // 떼고 나면 아무것도 안 남는 조각은 뜻이 아니다.
        #expect(KoreanGloss.tidy("좋다, .") == "좋다")
    }

    @Test("멀쩡한 뜻은 그대로 둔다")
    func 그대로() {
        #expect(KoreanGloss.tidy("생각하다") == "생각하다")
        #expect(KoreanGloss.tidy("사람, 누군가") == "사람, 누군가")
        #expect(KoreanGloss.tidy("긴장, 긴장감") == "긴장, 긴장감")
        // 물음표와 느낌표는 남긴다 — 감탄사와 되묻는 말에서는 그것이 뜻의 일부다.
        #expect(KoreanGloss.tidy("뭐야?") == "뭐야?")
        #expect(KoreanGloss.tidy("오!") == "오!")
    }
}
