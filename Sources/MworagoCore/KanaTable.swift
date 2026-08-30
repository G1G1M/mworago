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
