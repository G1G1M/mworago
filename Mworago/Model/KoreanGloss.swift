import Foundation

/// 모델이 옮겨 준 한국어 뜻을 화면에 올릴 만한 것으로 다듬는다.
///
/// 공개된 한일 사전이 없어 뜻을 온디바이스 모델로 굽는데(`Tools/Translator`),
/// 나오는 것이 고르지 않다. 구분자를 섞어 쓰고(`,` 485번 · `;` 101번), 같은 뜻을
/// 두 번 적고(766건 중 86건), 이따금 뜻 대신 설명을 늘어놓는다
/// (狙う → "무기를 가지고 있는 것과 같이 목표로 삼다").
///
/// **원본은 손대지 않는다.** 모델이 무엇이라 했는지는 그대로 남겨 두고,
/// 색인에 실을 때 이 문을 지나게 한다 — 그래야 나중에 판단을 바꿔도 다시 구울 필요가 없다.
public enum KoreanGloss {

    /// 뜻 하나가 이보다 길면 뜻이 아니라 설명으로 본다.
    ///
    /// 손으로 정한 값이 아니다. 766건 1,352조각을 재어 보니 길이가 중앙 3자,
    /// 90%가 5자, 95%가 8자인데 최대는 43자였다. 꼬리가 뚜렷하게 갈리는 자리라
    /// 12자를 넘는 22개(1.6%)만 걸린다.
    static let maxPieceLength = 12

    /// 화면에 싣는 뜻의 개수. 사전 자체가 영어 뜻을 둘까지만 담는다.
    static let maxPieces = 2

    /// 다듬은 뜻. 남는 것이 없으면 `nil` — 그 자리는 영어 뜻이 대신한다.
    ///
    /// 어설픈 한국어보다 정확한 영어가 낫다. 뜻 자리에 문장이 들어앉거나
    /// 옮기지도 못한 영어가 한국어인 척 앉아 있는 것이 사용자에게는 더 나쁘다.
    public static func tidy(_ raw: String) -> String? {
        var pieces: [String] = []
        for piece in stripParentheses(raw).split(whereSeparator: isSeparator) {
            let text = piece.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty,
                  text.count <= maxPieceLength,
                  // 한글이 한 자도 없으면 옮기지 못한 것이다 — "(not) particularly" 가 그대로 왔다.
                  text.contains(where: isHangul),
                  // 한 조각 안에 딴 나라 글자가 섞인 것도 옮기다 만 것이다
                  // ("네ighborhood" · "인형 Puppet" · "간단하다 plain하다").
                  // 조각 **사이**에 섞인 것은 이미 갈려서 걸러지므로 여기 걸리는 것은
                  // 한 낱말 안에서 두 언어가 엉킨 경우뿐이다.
                  !text.contains(where: isForeignLetter),
                  !pieces.contains(text)
            else { continue }
            pieces.append(text)
            if pieces.count == maxPieces { break }
        }
        return pieces.isEmpty ? nil : pieces.joined(separator: ", ")
    }

    /// 괄호와 그 안을 걷어낸다.
    ///
    /// 괄호 안은 영어 뜻의 부연을 그대로 옮긴 것이라 뜻이 아니다
    /// ("this, last (couple of years, etc.)" → "이, 마지막 (몇 년, 등)").
    /// **쪼개기 전에 걷어내야 한다** — 괄호 안에도 쉼표가 있어서, 먼저 쪼개면
    /// "마지막 (몇 년" 같은 반 토막이 남는다.
    /// 닫는 괄호가 없으면 거기서부터 끝까지를 부연으로 본다.
    private static func stripParentheses(_ raw: String) -> String {
        var result = ""
        var depth = 0
        for character in raw {
            if "([{（".contains(character) { depth += 1 }
            else if ")]}）".contains(character) { depth = max(0, depth - 1) }
            else if depth == 0 { result.append(character) }
        }
        return result
    }

    /// 뜻과 뜻을 가르는 것.
    ///
    /// 쉼표와 세미콜론 말고도 모델이 제멋대로 끼워 넣는 기호가 있다
    /// (`´` 14번 · `—` 5번 · `’` 4번 · `°` 와 `¸` 각 두 번 · `”` 와 `±` 각 한 번).
    /// 무엇을 뜻하는지 알 수 없으니 가르는 자리로 보고 걷어낸다 —
    /// 붙여 두면 낱말에 검불이 붙은 꼴이 된다(`실재”` · `잠깐만 봐봐——`).
    ///
    /// **물음표와 느낌표는 여기 없다.** `뭐야?` 와 `오!` 에서는 그것이 뜻의 일부다.
    /// **여기 없는 것은 재어 보니 없었기 때문이다.** `~` 를 예방 삼아 넣었다가
    /// 손으로 적은 기능어 표의 `~의` 가 `의` 로 깎였다. 나오지 않은 문자를 미리 막으면
    /// 막지 않아도 될 것을 막는다.
    private static func isSeparator(_ character: Character) -> Bool {
        ",;·/、，´’”“°¸±—–".contains(character)
    }

    private static func isHangul(_ character: Character) -> Bool {
        character.unicodeScalars.contains { $0.value >= 0xAC00 && $0.value <= 0xD7A3 }
    }

    /// 한국어 뜻 자리에 있어서는 안 되는 글자 — 로마자·가나·한자.
    ///
    /// 한자는 괄호 안에 단서로 들어오는 일이 있지만(`인격(人格)`) 그쪽은 괄호째
    /// 걷어내므로 여기까지 오지 않는다. 괄호 없이 남은 한자는 옮기다 만 것이다.
    private static func isForeignLetter(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x41...0x5A, 0x61...0x7A: true      // 로마자
            case 0xC0...0x24F: true                  // 로마자 확장 — "faveur" · "duy nhất"
            case 0x3040...0x30FF: true               // 가나
            case 0x4E00...0x9FFF: true               // 한자
            default: false
            }
        }
    }
}
