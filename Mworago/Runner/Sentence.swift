/// 조각들을 도로 한 문장으로 잇는다.
///
/// 검색 결과를 낱말 카드로만 늘어놓으면, 사용자가 원문을 머릿속으로 이어 붙이게 된다.
/// 애초에 문장을 치고 들어온 사람에게 문장을 돌려주지 않는 셈이다.
///
/// 이을 때 조심할 것이 하나 있다. **1위를 그냥 이어 붙이면 딴 문장이 된다** —
/// 활용을 되돌려 찾았기 때문에 조각이 사전형으로 돌아와 있다.
/// `이타이야메로` 를 이으면 `痛い止める` 가 되는데, 그건 아무도 하지 않은 말이다.
/// 사용자가 실제로 한 말은 `痛いやめろ` 다.
extension Segment {

    /// 문장에 놓일 이 조각의 글자.
    ///
    /// 규칙은 넷이고, 전부 "지어내지 않는다"는 한 가지 태도에서 나온다.
    ///  1. 못 찾은 조각은 **한글 그대로** 둔다 — 구멍이 문장에 보여야 어디가 틀렸는지 안다
    ///  2. 활용을 되돌렸으면 **되돌리기 전의 표면형**으로 되돌려 놓는다
    ///  3. 사전이 `uk`(보통 가나로 씀)라고 한 낱말은 한자를 꺼내지 않는다 — 자막도 그렇게 쓴다
    ///  4. 그 밖에는 한자 표기를 쓴다
    public var japanese: String {
        guard let top = results.first else { return hangul }
        if top.deinflection != nil { return Self.inflectedWriting(top) ?? top.matchedKana }
        if top.entry.usuallyKana { return top.reading }
        return top.headword
    }

    /// 활용형에 한자를 되살린다. 되살릴 근거가 없으면 nil.
    ///
    /// 되돌리기 전 표면형은 가나다(`おこって`). 그런데 **가나만으로는 낱말이 갈리지 않는다** —
    /// `おこる` 는 怒る(화내다)이기도 하고 起こる(일어나다)이기도 하다.
    /// 애플 번역기에 문장을 넘겨 보고 알았다. `彼はおこっている` 가 "그는 일어나고 있다"로
    /// 돌아왔는데, 번역기가 틀린 것이 아니라 우리가 한자를 잃고 넘긴 탓이었다.
    ///
    /// **지어내는 것이 아니다.** 사전이 그 낱말의 표기를 이미 알려 주었고, 어느 자리까지가
    /// 한자인지도 표기와 읽기를 맞대면 나온다 — 함께 끝나는 부분이 보내는 글자다
    /// (怒る·おこる 의 `る`, 食べる·たべる 의 `べる`). 그 앞자리만 한자로 바꾼다.
    private static func inflectedWriting(_ result: SearchResult) -> String? {
        // 사전이 uk 라고 한 낱말은 꺼내지 않는다. 자막도 가나로 쓴다.
        guard !result.entry.usuallyKana else { return nil }
        let writing = result.headword, reading = result.reading
        guard writing != reading else { return nil }

        let okurigana = commonSuffixCount(writing, reading)
        let writingStem = writing.dropLast(okurigana)
        let readingStem = reading.dropLast(okurigana)
        // 표면형이 사전형 어간으로 시작하지 않으면 어디를 바꿀지 알 수 없다(来る → きた).
        guard !writingStem.isEmpty, !readingStem.isEmpty,
              result.matchedKana.hasPrefix(readingStem)
        else { return nil }
        return String(writingStem) + result.matchedKana.dropFirst(readingStem.count)
    }

    /// 두 글자열이 함께 끝나는 글자 수.
    private static func commonSuffixCount(_ a: String, _ b: String) -> Int {
        var count = 0
        for (x, y) in zip(a.reversed(), b.reversed()) {
            guard x == y else { break }
            count += 1
        }
        return count
    }

    /// 문장에 놓일 이 조각의 소리.
    ///
    /// 소리를 듣고 찾아온 사람에게 가장 가까운 것이 가나다. 여기서도 사전형이 아니라
    /// 사용자가 실제로 말한 표면형이어야 한다.
    public var kana: String {
        guard let top = results.first else { return hangul }
        return top.deinflection != nil ? top.matchedKana : top.reading
    }
}

extension Array where Element == Segment {

    /// 되살린 원문. 일본어는 띄어 쓰지 않으므로 그대로 붙인다.
    public var japanese: String { map(\.japanese).joined() }

    /// 번역기에 넘길 원문. **한자를 살려서 준다.**
    ///
    /// 한때 가나로만 넘겼다. 우리가 1위를 잘못 고른 자리에서 한자를 박으면 그 오류가
    /// 굳는다고 보았기 때문이다 — `さけ`(酒)를 `避け`로 골라 "술에 취해 있다"가
    /// "피하기 위해 빠져들고 있다"가 된 일이 실제로 있었다.
    ///
    /// **그런데 재어 보니 잃는 쪽이 더 컸다.** 히라가나만 이어진 문장은 번역기도 낱말을
    /// 가르지 못해 통째로 딴 말이 된다.
    ///
    ///     彼はうそをついたと彼女を責めた
    ///       가나 → 그는 거짓말을 했다는 여자애를 괴롭혔다
    ///       한자 → 그는 거짓말을 했다고 그녀를 비난했다
    ///
    ///     彼は氷の上ですべった
    ///       가나 → 그는 눈 위에 있습니다
    ///       한자 → 그는 얼음 위에서 미끄러지고 있습니다
    ///
    /// **갈라 보이는 후보가 없는 낱말만 한자로 주는 길도 재어 보았다.** 그 편이 안전할 줄
    /// 알았는데 한자만 못했다 — `彼`·`氷` 처럼 흔한 낱말도 대안을 달고 있어서 죄다
    /// 가나로 빠졌다. "확신"의 기준으로 삼기에 그 잣대는 너무 느슨하다.
    ///
    /// 우리가 낱말을 잘못 고르면 어차피 틀린다. 그때 가나로 둔다고 구제되지 않는다는 것도
    /// 함께 보았다(`年` 를 `都市` 로 고른 문장은 어느 쪽으로 넘겨도 틀렸다).
    public var forTranslation: String { japanese }

    /// 되살린 원문의 소리.
    public var kana: String { map(\.kana).joined() }
}
