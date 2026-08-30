/// 낱말의 큰 갈래.
///
/// JMdict 의 품사 태그는 쉰 가지가 넘는다(`v5u`·`v5k`·`vs-i`…). 그 결을 다 살릴 일은 없고,
/// 실제로 갈라야 하는 것은 **한국어로 옮길 때 어미가 어떻게 끝나는가**와
/// **애초에 옮길 수 있는 낱말인가** 둘뿐이다.
public enum WordClass: String, Sendable {
    /// 동사. 한국어 뜻은 "-다"로 끝나야 한다 — `思う`가 "생각"이 아니라 "생각하다"인 것.
    case verb
    /// 형용사·형용동사. 이쪽도 "-다"로 끝난다.
    case adjective
    case noun
    case adverb
    /// 조사·조동사·계사. **뜻이 아니라 기능이다.**
    /// 사전의 영어 뜻부터가 낱말이 아니라 설명문이라(`の` → "indicates possessive"),
    /// 그대로 옮기면 뜻 자리에 문장이 들어앉는다.
    case function
    /// 관용 표현(`exp`). `だろう`·`だった`·`んだ` 처럼 낱말이 아니라 굳어진 말투다.
    /// 사전 뜻도 "seems"·"the reason is that ..." 처럼 문장 조각이라 옮기면 그대로 문장이 된다.
    case expression
    /// 접두사·접미사(`pref`·`suf`). `さん`·`お` 는 혼자 서지 못하고 붙어야 뜻이 산다.
    /// 실측에서 `さん`(Mr, Mrs)이 "시스터, 브레이어"로, `お`가 "오!"로 돌아왔다.
    case affix
    /// 품사를 모르는 것. 기능어로 몰지 않는다 — 그러면 멀쩡한 낱말이 통째로 빠진다.
    case other

    /// 낱말 뜻으로 옮길 수 있는가.
    /// 낱말 뜻으로 옮길 수 있는가.
    ///
    /// **감탄사는 옮긴다.** `ありがとう`는 뜻이 있는 낱말이고, 애니에서 가장 많이 들리는 말이다 —
    /// 혼자 서지 못하는 접사나 문장 조각인 관용구와는 사정이 다르다.
    public var isTranslatable: Bool {
        switch self {
        case .function, .expression, .affix: false
        case .verb, .adjective, .noun, .adverb, .other: true
        }
    }

    /// 프롬프트에 적어 줄 이름. 모르면 적지 않는 편이 낫다.
    public var koreanName: String? {
        switch self {
        case .verb: "동사"
        case .adjective: "형용사"
        case .noun: "명사"
        case .adverb: "부사"
        case .function, .expression, .affix, .other: nil
        }
    }

    /// JMdict 품사 태그들에서 갈래를 정한다.
    ///
    /// 한 낱말이 태그를 여럿 단다(`大丈夫`는 `adj-na`와 `n`을 겸한다).
    /// **먼저 쓰인 쪽이 그 낱말의 얼굴이므로** 태그 순서대로 훑어 처음 잡히는 갈래를 쓴다.
    ///
    /// **순서가 전부다.** 어느 갈래를 우선할지 정하려고 두 번 헤맸는데, 둘 다 틀렸다.
    /// 기능 태그를 먼저 보면 する(`vs-i·vi·vt·suf·aux-v`)와 見る(`v1·vt·aux-v`)가
    /// 뒤에 붙은 suf·aux-v 때문에 삼켜져, 애니에서 가장 흔한 동사 여덟이 뜻을 잃는다.
    /// 실질 품사를 먼저 보면 이번엔 も(`prt·adv`)와 と(`prt·conj·n`)가 부사와 명사로
    /// 새어 나가 "도움’를 줄’것—" 같은 것이 뜻 자리에 앉는다.
    ///
    /// **JMdict 는 주된 품사를 먼저 적는다.** する 는 vs-i 가 먼저고 も 는 prt 가 먼저다.
    /// 우선순위를 내가 정할 일이 아니라 사전이 적은 차례를 그대로 따르면 양쪽이 다 맞는다.
    public init(tags: [String]) {
        for tag in tags {
            if Self.functionTags.contains(tag) { self = .function; return }
            if tag == "exp" { self = .expression; return }
            if Self.affixTags.contains(tag) { self = .affix; return }
            // `vs`(する가 붙는 낱말)는 동사 태그가 아니라 명사에 붙는 표지다.
            // 그런 낱말은 `n` 을 먼저 달고 있으므로 이 차례가 알아서 걸러 준다(勉強 = n·vs).
            if tag.hasPrefix("v") && !tag.hasPrefix("vulg") { self = .verb; return }
            if tag.hasPrefix("adj") { self = .adjective; return }
            if tag.hasPrefix("adv") { self = .adverb; return }
            if tag == "n" || tag.hasPrefix("n-") || tag == "pn" { self = .noun; return }
        }
        self = .other
    }

    /// 조사(`prt`) · 조동사(`aux`·`aux-v`·`aux-adj`) · 계사(`cop`) · 접속사(`conj`).
    private static let functionTags: Set<String> = ["prt", "aux", "aux-v", "aux-adj", "cop", "conj"]

    /// 접두사·접미사. `n-suf`·`n-pref` 는 명사를 겸하므로 여기 넣지 않는다 — 그쪽은 혼자서도 뜻이 선다.
    private static let affixTags: Set<String> = ["pref", "suf", "ctr"]
}
