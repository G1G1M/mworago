import SwiftUI
import MworagoCore

/// 담기 모달 — **어디에 담을지 담는 순간에 묻는다.**
///
/// 한때는 책장에서 "지금 담는 곳"을 미리 정해 두고 담을 때는 묻지 않았다. 담는 순간에
/// 물으면 흐름이 끊긴다는 판단이었는데, 대가가 더 컸다 — **앱은 사용자가 어느 화를
/// 보는지 알 수 없다.** 날짜로 묶은 것도 그것을 몰라서 쓴 대용품이었고, 미리 정해 두는
/// 자리도 "정해 두는 것을 잊지 않는" 사람에게만 맞았다. 아는 사람에게 묻는 편이 정확하다.
///
/// 대신 **지난번에 넣은 곳이 이미 골라져 있다.** 한 화를 몰아 담는 동안은 같은 곳이
/// 계속 위에 있으므로, 고르는 일이 확인하는 일이 된다.
///
/// **고르고 나서 저장한다.** 한때는 줄을 누르는 순간 담기고 닫혔다 — 탭 하나를 아끼는
/// 쪽이었는데, 쓰는 사람에게는 **폼처럼 생긴 것이 메뉴로 동작하는** 화면이었다.
/// 지난번 자리에 점이 이미 찍혀 있으니 "골라져 있다"로 읽히는데, 그 줄을 다시 눌러야
/// 담긴다. 점의 뜻이 둘(기억한 자리 · 지금 고른 것)로 갈려 있던 것이다.
///
/// 이제 점은 **지금 고른 것** 하나만 가리키고(열 때 지난번 자리로 놓인다), 담는 것은
/// `저장` 이 한다. 탭이 하나 늘지만 "무엇이 담길지"가 누르기 전에 화면에 있다.
///
/// **화면 가운데 뜨는 판이다.** 아래에서 올라오는 시트는 "다음 화면"의 몸짓인데,
/// 이것은 갈피표를 누른 그 자리에서 한 가지를 묻고 곧 물러나는 일이다.
/// 책장의 새 묶음·이름 바꾸기·옮기기가 모두 같은 판을 쓴다.
struct FolderPicker: View {
    let word: CollectedWord
    /// 고를 수 있는 묶음들. 지난번에 넣은 곳은 낱말이 없어도 여기 들어 있다.
    let folderNames: [String]
    /// 지난번에 넣은 곳. 미리 골라 두는 자리이고, `nil` 이면 "안 넣기"가 골라져 있다.
    let lastFolder: String?
    /// 담는다. `nil` 은 아무 묶음에도 넣지 않는다는 뜻이다.
    var onPick: (String?) -> Void
    /// 물음. 담을 때와 옮길 때가 다르다.
    ///
    /// **옮기기도 같은 모달을 쓴다.** 고르는 일이 같은데 화면이 다르면 새 문법을
    /// 하나 더 배워야 하고, 옮기기 쪽에만 "새 묶음 만들기"가 빠지는 일도 생긴다.
    var prompt: String = "어디에 담을까요?"
    /// 점이 찍힌 자리에 붙는 말. 담을 때는 `지난번`, 옮길 때는 `지금`이다.
    var markLabel: String = "지난번"

    /// 판을 닫는다. **`@Environment(\.dismiss)` 를 쓰지 않는다** — 시트가 아니라
    /// 화면 위에 덧그린 판이라, 그 길로 닫으면 판이 아니라 뒤에 있는 화면이 닫힌다.
    var onClose: () -> Void = {}

    /// 지금 고른 자리. **`nil` 과 "안 고름"이 다르므로** 옵셔널을 겹쳐 쓰지 않고
    /// 갈래로 적는다 — `nil` 은 "나중에 정하기"라는 **고른 값**이다.
    enum Pick: Equatable {
        case folder(String)
        case later
        var name: String? { if case .folder(let n) = self { n } else { nil } }
    }
    @State private var picked: Pick

    /// 새 묶음 이름을 받는 중인가.
    ///
    /// **묶음이 하나도 없으면 펼친 채로 연다.** "폴더가 없으면 거기서 만든다"는 것이
    /// 이 모달의 절반인데, 빈 목록에 만들기 버튼 하나만 놓으면 그것을 한 번 더 누르게 한다.
    @State private var naming: Bool
    @State private var newName = ""
    @FocusState private var nameFocused: Bool

    init(word: CollectedWord, folderNames: [String], lastFolder: String?,
         onPick: @escaping (String?) -> Void,
         onClose: @escaping () -> Void = {},
         prompt: String = "어디에 담을까요?", markLabel: String = "지난번") {
        self.word = word
        self.folderNames = folderNames
        self.lastFolder = lastFolder
        self.onPick = onPick
        self.onClose = onClose
        self.prompt = prompt
        self.markLabel = markLabel
        // `--naming` 은 이름 받는 칸을 펼친 채 띄운다. `--collecting` 과 같은 취지 —
        // 시뮬레이터는 손으로 두드릴 수 없어 이 상태를 눈으로 볼 길이 없다.
        _naming = State(initialValue: folderNames.isEmpty || LaunchOptions.current.has("naming"))
        _picked = State(initialValue: lastFolder.map(Pick.folder) ?? .later)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            head
            // **줄이 적으면 스크롤을 두지 않는다.** `ScrollView` 는 준 높이를 늘 다
            // 차지해서, 묶음이 둘뿐인데도 판 아래가 그만큼 비어 보인다.
            if folderNames.count > 5 {
                ScrollView { folderRows }
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(height: 232)
            } else {
                folderRows
            }
            // 묶음을 정하지 않고 담는다. **첫 낱말을 담으려고 폴더부터 만들게 하지
            // 않는다.** 이렇게 담은 것은 책장의 "아직 안 넣은 것"으로 모이고,
            // 상세에서 나중에 옮길 수 있다 — 이름이 그것을 말해 준다.
            //
            // **묶음 줄에 바로 이어 붙인다.** 점이 있는 것은 고를 수 있는 것이라는 게
            // 이 판의 문법인데, 사이에 선을 그으면 같은 문법을 쓰는 줄들이 다른 무리로
            // 보인다. 고를 것은 한 덩어리로 두고, 선은 **고르는 일과 만드는 일** 사이에
            // 한 번만 긋는다.
            row(name: "나중에 정하기",
                picked: picked == .later,
                dim: true) { picked = .later }
            DialogDivider()
            NewFolderField(naming: $naming,
                           name: $newName,
                           focused: $nameFocused,
                           canFold: !folderNames.isEmpty,
                           onCreate: createAndPick)
            confirm
        }
        .padding(.vertical, 20)
    }

    private var folderRows: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(folderNames, id: \.self) { name in
                row(name: name, picked: picked == .folder(name)) { picked = .folder(name) }
            }
            // **방금 만든 자리도 줄로 선다.** 이름을 적어 만들면 그 자리가 골라지는데,
            // 목록은 아직 그것을 모른다(밖에서 받은 값이고 저장할 때 비로소 생긴다).
            // 줄이 없으면 점이 어디에도 안 찍혀, 고른 것이 화면에서 사라진 것처럼 보인다.
            if let name = picked.name, !folderNames.contains(name) {
                row(name: name, picked: true, isNew: true) { }
            }
        }
    }

    /// 담기와 그만두기.
    ///
    /// **`저장` 만 검게 채운다.** 이 판에서 검게 채워지는 것은 고른 자리의 점과 이 단추
    /// 둘인데, 하나는 "무엇을"이고 하나는 "그래서 어떻게"라 겹치지 않는다.
    private var confirm: some View {
        DialogActions(confirmTitle: "저장",
                      onConfirm: { pick(picked.name) },
                      onCancel: onClose)
            // 만드는 줄과 조금 더 벌린다. 위는 판 안에서 고르고 만드는 일이고 여기는
            // 판을 닫는 일이라, 줄 사이 간격과 같으면 한 목록의 마지막 줄로 읽힌다.
            .padding(.top, 20)
    }

    /// 무엇을 담는 중인지 말해 준다. 갈피표를 누른 뒤 모달이 뜨는 사이에 시선이
    /// 옮겨 가므로, 어느 낱말이었는지 여기서 한 번 더 짚어 준다.
    private var head: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(prompt)
                .font(Theme.korean(.title))
                .foregroundStyle(Theme.ink)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(word.reading)
                    .font(Theme.japanese(.body))
                    .foregroundStyle(Theme.grey1)
                    .lineLimit(1)
                // 무엇을 담는지 화면마다 같은 말로 알린다 — 카드·책장·연습이 다 이 꼬리표를 쓴다.
                if let 품사 = word.partOfSpeech { PartOfSpeechTag(name: 품사) }
                if !word.gloss.isEmpty {
                    Text(word.gloss)
                        .font(Theme.korean(.sub))
                        .foregroundStyle(Theme.grey2)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    /// 묶음 한 줄. 왼쪽 점이 **지금 고른 자리**를 가리킨다.
    ///
    /// 열 때는 지난번에 넣은 곳에 놓여 있다. 그래서 한 화를 몰아 담는 동안은
    /// 고르는 일이 없고 `저장` 만 누르면 된다.
    private func row(name: String, picked: Bool, dim: Bool = false, isNew: Bool = false,
                     action: @escaping () -> Void) -> some View {
        RadioRow(title: name, isPicked: picked, dim: dim, singleLine: false, action: action) {
            // **지난번 자리는 고른 것과 따로 말한다.** 다른 곳을 골라도 이 표는
            // 그 자리에 남아, 원래 어디에 넣어 왔는지가 화면에서 안 사라진다.
            if isNew {
                Text("새 묶음")
                    .font(Theme.korean(.tag))
                    .foregroundStyle(Theme.grey2)
            } else if name == lastFolder || (name == "나중에 정하기" && lastFolder == nil) {
                Text(markLabel)
                    .font(Theme.korean(.tag))
                    .foregroundStyle(Theme.grey2)
            }
        }
        .accessibilityHint(picked ? "지금 고른 자리입니다" : "")
    }

    private var trimmedName: String {
        newName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 이름을 받아 그 자리를 고른 상태로 만든다. 담기는 `저장` 이 한다.
    private func createAndPick() {
        guard !trimmedName.isEmpty else { return }
        picked = .folder(trimmedName)
        naming = false
        nameFocused = false
        newName = ""
    }

    private func pick(_ folder: String?) {
        onPick(folder)
        onClose()
    }
}
