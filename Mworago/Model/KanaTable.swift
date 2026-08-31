import Foundation

/// 훈령식 로마자와 히라가나 사이의 변환표.
///
/// 헵번식(shi, chi, jo) 대신 훈령식(si, ti, zyo)을 쓰는 이유는 규칙성 때문이다.
/// 훈령식은 `자음 + 모음`이 예외 없이 맞아떨어져서, 오십음도를 일일이 적지 않고
/// 행(자음) × 단(모음)으로 표를 생성할 수 있다. 요음도 `자음 + y + 모음`으로 균일하다.
public enum KanaTable {

    static let vowels: [Character] = ["a", "i", "u", "e", "o"]

    /// 행마다 あいうえお 다섯 단. 빈 칸(ゐ·ゑ 등 현대에 안 쓰는 자리)은 nil.
    private static let rows: [(consonant: String, kana: [String?])] = [
        ("",  ["あ", "い", "う", "え", "お"]),
        ("k", ["か", "き", "く", "け", "こ"]),
        ("g", ["が", "ぎ", "ぐ", "げ", "ご"]),
        ("s", ["さ", "し", "す", "せ", "そ"]),
        ("z", ["ざ", "じ", "ず", "ぜ", "ぞ"]),
        ("t", ["た", "ち", "つ", "て", "と"]),
        ("d", ["だ", "ぢ", "づ", "で", "ど"]),
        ("n", ["な", "に", "ぬ", "ね", "の"]),
        ("h", ["は", "ひ", "ふ", "へ", "ほ"]),
        ("b", ["ば", "び", "ぶ", "べ", "ぼ"]),
        ("p", ["ぱ", "ぴ", "ぷ", "ぺ", "ぽ"]),
        ("m", ["ま", "み", "む", "め", "も"]),
        ("y", ["や", nil, "ゆ", nil, "よ"]),
        ("r", ["ら", "り", "る", "れ", "ろ"]),
        ("w", ["わ", nil, nil, nil, "を"]),
    ]

    /// 요음을 만들 수 없는 행. や·わ행은 이미 반모음이고, あ행은 자음이 없다.
    private static let noYoon: Set<String> = ["", "y", "w"]

    private static let table: [String: String] = {
        var table: [String: String] = [:]

        for row in rows {
            for (index, kana) in row.kana.enumerated() {
                guard let kana else { continue }
                table[row.consonant + String(vowels[index])] = kana
            }

            // 요음: い단 가나 뒤에 작은 ゃ·ゅ·ょ를 붙인다. きゃ = き + ゃ
            guard !noYoon.contains(row.consonant), let iKana = row.kana[1] else { continue }
            for (small, vowel) in [("ゃ", "a"), ("ゅ", "u"), ("ょ", "o")] {
                table[row.consonant + "y" + vowel] = iKana + small
            }
        }

        table["n"] = "ん"   // 발음(撥音)
        table["Q"] = "っ"   // 촉음(促音). 뒤 자음이 겹치는 자리라 로마자 표기가 따로 없어 대문자로 표시한다.
        return table
    }()

    /// 가타카나를 히라가나로. 두 표는 같은 순서로 배열돼 있어 오프셋만 빼면 된다.
    ///
    /// 사전 조회 전에 반드시 거쳐야 한다. JMdict 는 외래어 표제어를 가타카나로 싣는데
    /// (`ポイント`), 규칙이 만드는 후보는 히라가나(`ぽいんと`)라 그냥 두면 영영 만나지 못한다.
    public static func toHiragana(_ text: String) -> String {
        String(String.UnicodeScalarView(text.unicodeScalars.map { scalar in
            (0x30A1...0x30F6).contains(scalar.value)
                ? Unicode.Scalar(scalar.value - 0x60)! : scalar
        }))
    }

    /// 가타카나로. `toHiragana` 의 짝이다.
    ///
    /// 두 표는 유니코드에서 같은 순서로 배열돼 있어 오프셋만 더하면 된다.
    /// 사전 조회에는 쓰지 않는다 — 조회는 히라가나로 모은다. 이것은 **화면에 보이려고**
    /// 있다(가나 표를 가타카나로 넘겨 볼 때).
    public static func toKatakana(_ text: String) -> String {
        String(String.UnicodeScalarView(text.unicodeScalars.map { scalar in
            (0x3041...0x3096).contains(scalar.value)
                ? Unicode.Scalar(scalar.value + 0x60)! : scalar
        }))
    }

    /// 오십음도를 화면에 그릴 수 있게 내어 준다.
    ///
    /// 규칙 표(`table`)는 로마자에서 가나를 찾는 사전이라 **차례가 없다.** 배우는 사람에게
    /// 필요한 것은 그 차례다 — あ か さ た な 로 내려가고 あいうえお 로 건너가는 격자.
    /// 그래서 같은 자료를 보는 결을 따로 낸다.
    ///
    /// 청음·탁음·요음을 가른 것은 셋이 배우는 차례이기 때문이다. 한 표에 몰아 넣으면
    /// 오십음도가 아니라 백 몇 자짜리 낱글자 더미가 된다.
    public struct Chart: Sendable {
        public let title: String
        public let rows: [[String?]]
    }

    public static let charts: [Chart] = {
        func kana(of consonants: [String]) -> [[String?]] {
            consonants.compactMap { c in rows.first { $0.consonant == c }?.kana }
        }
        // 요음은 い단 가나에 작은 ゃゅょ 를 붙인 것이라 세 칸뿐이다.
        let yoonConsonants = ["k", "g", "s", "z", "t", "d", "n", "h", "b", "p", "m", "r"]
        let yoon: [[String?]] = yoonConsonants.map { c in
            ["a", "u", "o"].map { table[c + "y" + $0] }
        }
        return [
            Chart(title: "청음", rows: kana(of: ["", "k", "s", "t", "n", "h", "m", "y", "r", "w"])
                                        + [["ん", nil, nil, nil, nil]]),
            Chart(title: "탁음 · 반탁음", rows: kana(of: ["g", "z", "d", "b", "p"])),
            Chart(title: "요음", rows: yoon),
        ]
    }()

    /// 로마자 모라 하나를 가나로. 일본어에 없는 소리면 nil.
    public static func kana(for mora: String) -> String? {
        table[mora]
    }

    /// 로마자 모라 열을 가나 문자열로. 하나라도 변환할 수 없으면 전체가 nil.
    public static func compose(_ morae: [String]) -> String? {
        var result = ""
        for mora in morae {
            guard let kana = kana(for: mora) else { return nil }
            result += kana
        }
        return result
    }
}
