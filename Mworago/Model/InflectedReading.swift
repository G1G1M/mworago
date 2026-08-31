import Foundation

/// 표제어의 읽기에서 활용형의 읽기를 만든다.
///
/// 사전은 표제어의 읽기만 적는다(`読む(よむ)`). 문장에 `読んだ` 로 나타났을 때의
/// 발음 `よんだ` 는 어디에도 없으므로 만들어 내야 한다.
///
/// **한자 어간의 읽기는 활용해도 변하지 않는다** — 그래서 표제어에서 어간의 읽기를
/// 떼어 내 표면형의 어미에 붙이면 된다.
///
///     読む(よむ) + 読んだ  →  어간 読 = よ, 어미 む → んだ  ⇒  よんだ
public enum InflectedReading {

    public static func make(headword: String, reading: String, surface: String) -> String? {
        // 표면형이 전부 가나면 그 자체가 읽기다 (する{してる})
        if surface.allSatisfy(\.isKana) { return surface }

        let stem = headword.prefix { !$0.isKana }
        guard !stem.isEmpty, surface.hasPrefix(stem) else { return nil }

        let headwordTail = headword.dropFirst(stem.count)
        let surfaceTail = surface.dropFirst(stem.count)
        guard reading.hasSuffix(headwordTail), surfaceTail.allSatisfy(\.isKana) else { return nil }

        if let irregular = kaIrregular(headword: headword, reading: reading, tail: surfaceTail) {
            return irregular
        }
        return String(reading.dropLast(headwordTail.count)) + String(surfaceTail)
    }

    /// `来る` 만은 어간의 읽기가 활용에 따라 갈린다.
    ///
    /// 일본어에서 カ行変格活用을 하는 동사는 이것 하나뿐이다. 어간을 그대로 두는
    /// 규칙을 들이대면 `来た` 가 `くた`(→ きた), `来ない` 가 `くない`(→ こない)가 된다.
    /// 2,000개 케이스 중 67개(3.4%)가 그렇게 굳어 있었고, 그 케이스는 입력부터
    /// 틀린 음차라 무엇을 고쳐도 맞힐 수 없었다.
    ///
    /// | 어미 | 어간 | 보기 |
    /// |---|---|---|
    /// | る · れば | く | 来る · 来れば |
    /// | い | こ | 来い(명령형) |
    /// | な · よ · ら · さ · ぬ · ず · れ(ば 아닌) | こ | 来ない · 来よう · 来られる · 来れる |
    /// | 그 밖 · 없음 | き | 来た · 来て · 来ます · 来 |
    ///
    /// `出来る`·`来週` 처럼 来 가 들었을 뿐인 낱말은 건드리지 않는다 —
    /// 어간이 `出来`(でき)·`来週`(らいしゅう)라 여기 걸리면 오히려 망가진다.
    private static func kaIrregular(headword: String, reading: String,
                                    tail: Substring) -> String? {
        guard headword == "来る", reading == "くる" else { return nil }
        let stem: String
        switch tail.first {
        case "る":                                stem = "く"
        // 来れば(가정형)는 く 인데, ら 를 뺀 가능형 来れる 는 来られる 의 축약이라 こ 다.
        case "れ":                                stem = tail.hasPrefix("れば") ? "く" : "こ"
        case "い":                                stem = "こ"
        case "な", "よ", "ら", "さ", "ぬ", "ず":     stem = "こ"
        default:                                  stem = "き"
        }
        return stem + String(tail)
    }
}

public extension Character {
    /// 히라가나·가타카나·장음 부호
    var isKana: Bool {
        unicodeScalars.allSatisfy { (0x3041...0x30FF).contains($0.value) }
    }
}
