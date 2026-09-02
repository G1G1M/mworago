import SwiftUI
import MworagoCore

/// 묶음 하나를 펼친 화면.
///
/// 책장 목록에서 묶음 이름을 누르면 여기로 **파고든다.**
///
/// 전에는 목록에서 낱말을 그 자리에 다 펼쳤다. 한 편만 봤을 때는 괜찮았지만 다섯 편이
/// 쌓이면 책장이 다섯 배로 길어지고, 스무 편이면 훑을 수 없는 화면이 된다.
///
/// **화면을 건너뛰는 것과 파고드는 것은 다르다.** 낱말을 누르면 찾기 탭으로 튕기던 것을
/// 상세 시트로 바꾼 것은 *옆으로 새는 것*을 막은 일이었다. 묶음에 들어가는 것은 갈래를
/// 따라 내려가는 일이라, 뒤로가 길을 그대로 지킨다.
///
/// **여기가 묶음을 손보는 자리다.** 담기 모달이 묶음을 만들 수만 있게 해 두면 오타를 낸
/// 이름이 영영 남는다. 만드는 길을 냈으면 고치고 없애는 길도 있어야 한다.
struct FolderDetail: View {
    let title: String
    let words: [CollectedWord]
    /// 이름 붙은 묶음이면 그 이름.
    ///
    /// 날짜 묶음이나 "아직 안 넣은 것"이면 `nil` 이다 — **이름을 바꾸거나 없애는 일은
    /// 사용자가 지은 이름에만 있다.** 날짜는 앱이 센 것이라 고칠 것이 아니고,
    /// 안 넣은 것은 묶음이 아니라 아직 묶이지 않았다는 상태다.
    var folder: String? = nil
    var onPractice: ([CollectedWord]) -> Void = { _ in }
    var onRename: (String, String) -> Void = { _, _ in }
    var onRemoveFolder: (String) -> Void = { _ in }
    /// 낱말 상세가 쓰는 길들. 책장 목록에서 여는 것과 **같은 시트**라
    /// 여기서만 버튼이 먹통이면 같은 화면이 자리에 따라 다르게 구는 것이 된다.
    var onFind: (String) -> Void = { _ in }
    var onRemoveWord: (CollectedWord) -> Void = { _ in }
    var onMoveWord: (CollectedWord, String?) -> Void = { _, _ in }
    var folderNames: [String] = []

    @Environment(\.dismiss) private var dismiss
    /// 펼쳐 보고 있는 낱말. 목록에서와 같은 상세 시트를 쓴다.
    @State private var detail: CollectedWord?
    @State private var renaming = false
    /// 이 묶음에 할 수 있는 일들이 펼쳐져 있는가.
    @State private var menuOpen = false
    /// 실행 인자로 열라던 것을 이미 열었는가. 뷰보다 오래 사는 곳에 둔다 —
    /// 뒤로 나갔다 다시 들어올 때마다 목록이 펼쳐지면 안 된다.
    private static var openedFromArguments = false
    @State private var removing = false
    /// 지우는 손이 얹혔는가. 책장 첫 화면과 같은 문법이다 —
    /// 미는 몸짓 대신 편집 자리를 두고, 지울 셈일 때만 단추를 보인다.
    @State private var editing = false

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    head
                    if words.isEmpty { emptyWords }
                    ForEach(words) { word in
                        HStack(spacing: 0) {
                            if editing {
                                Button { onRemoveWord(word) } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 21))
                                        .foregroundStyle(.red)
                                        .padding(.leading, Theme.gutter)
                                        .padding(.vertical, 8)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("지우기")
                            }
                            row(word)
                        }
                        Divider().overlay(Theme.grey3).padding(.horizontal, Theme.gutter)
                    }
                }
                .padding(.bottom, Theme.screenBottom)
                // 훑는 목록이지만 가나와 뜻이 **두 열로 갈린다.** 목록 폭(640)을 쓰면
                // 아이패드에서 두 열이 멀어져 한 줄을 눈으로 가로질러야 한다.
                .frame(maxWidth: Theme.readWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        // **제목은 화면 안에서 말한다.** 내비 바에도 두면 같은 이름이 두 번 나온다 —
        // 책장 루트에서 내비 바를 숨긴 것과 같은 까닭이다. 바는 뒤로 가는 길로만 쓴다.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $detail) { word in
            WordDetail(word: word,
                       onFind: onFind,
                       onRemove: onRemoveWord,
                       onMove: { word, folder in
                           onMoveWord(word, folder)
                           // 옮긴 결과를 시트에 되비춘다. 넘겨받은 `words` 는 이 시트를
                           // 열 때의 것이라, 다시 찾아도 옮기기 전 값이 나온다.
                           detail = word.movedTo(folder)
                       },
                       folderNames: folderNames)
        }
        // `--menu` 로 할 수 있는 일 목록을 펼친 채 띄운다. `--folder=` · `--detail` 과
        // 같은 취지 — 시뮬레이터는 손으로 두드릴 수 없어 이 목록을 눈으로 볼 길이 없다.
        .onAppear {
            guard !Self.openedFromArguments else { return }
            Self.openedFromArguments = true
            if ProcessInfo.processInfo.arguments.contains("--menu") { menuOpen = true }
        }
        // 책장의 "새 묶음"과 같은 판을 쓴다. 이름을 만드는 일과 고치는 일이
        // 다른 얼굴로 뜨면 같은 일을 두 번 배워야 한다.
        .dialog(isPresented: $renaming) {
            FolderNameDialog(title: "이름 바꾸기",
                             hint: "이 묶음에 담긴 낱말이 다 따라갑니다.",
                             placeholder: title,
                             existing: folderNames.filter { $0 != folder },
                             mergesOnDuplicate: true,
                             confirmLabel: "바꾸기",
                             initialName: title,
                             isPresented: $renaming) { newName in
                if let folder { onRename(folder, newName) }
                // 이름이 바뀌면 이 화면이 가리키던 묶음이 없다. 판은 화면 위에 덧그린
                // 것이라 화면과 함께 사라지므로, 시트 때처럼 닫히기를 기다릴 것이 없다.
                dismiss()
            }
        }
        .alert("묶음을 없앨까요?", isPresented: $removing) {
            Button("없애기", role: .destructive) {
                if let folder { onRemoveFolder(folder) }
                dismiss()
            }
            Button("그만두기", role: .cancel) { }
        } message: {
            // 무엇이 남는지 먼저 말한다. 담은 것이 사라진다고 오해하면 누를 수 없다.
            // 빈 묶음에는 남을 낱말이 없으므로 그 말을 하지 않는다 — 없는 것을 세면
            // "낱말 0개는 그대로 남고" 처럼 읽을 수 없는 말이 된다.
            Text(words.isEmpty
                 ? "담긴 낱말이 없어 이름만 없어집니다."
                 : "담은 낱말 \(words.count)개는 그대로 남고 '아직 안 넣은 것'으로 갑니다. 이름만 없어집니다.")
        }
    }

    /// 이름과 개수, 그리고 이 묶음에 할 수 있는 일.
    private var head: some View {
        VStack(alignment: .leading, spacing: 14) {
            // **이름과 할 일이 한 줄에 마주 선다.** 줄을 나눠 두면 이름 아래 캡슐이
            // 목록의 첫 줄처럼 읽혀서, 이 묶음에 하는 일인지 낱말에 하는 일인지 갈리지 않는다.
            // 이름은 왼쪽 끝, 할 일은 오른쪽 끝 — 그 사이가 비어 있어 둘이 다른 일임이 보인다.
            HStack(alignment: .center, spacing: 9) {
                // 이름과 개수는 서로 밑줄을 맞추고, 동그란 단추는 그 줄에 가운데로 선다.
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Text(title)
                        .font(Theme.korean(22, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    // 개수는 담긴 것이 있을 때만 적는다. `0개` 는 아래 안내가 이미 하는 말이고,
                    // 이름 옆에 붙으면 빈 자리를 세어 보라는 말처럼 읽힌다.
                    if !words.isEmpty {
                        Text("\(words.count)개")
                            .font(Theme.korean(13))
                            .foregroundStyle(Theme.grey3)
                    }
                }

                Spacer(minLength: 12)

                // **할 수 있는 일은 전부 이 안에 있다.**
                //
                // 연습만 밖에 캡슐로 세워 두었는데, 그러면 이름 옆에 크기가 다른 것이
                // 둘 서고 "이 묶음에 무엇을 할 수 있는지"가 두 자리로 갈린다.
                // 한 자리에서 열어 고르면 그 목록이 곧 답이다.
                if !words.isEmpty || folder != nil { moreButton }
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, Theme.screenTop)
        .padding(.bottom, Theme.blockGap)
    }

    /// 이 묶음에 할 수 있는 일을 여는 단추.
    ///
    /// **동그랗다.** 납작한 캡슐은 글자를 담으려고 옆으로 늘인 꼴인데 여기 담긴 것은
    /// 점 세 개뿐이라, 가로로 늘이면 빈 자리만 넓어진다. 기호 하나에는 원이 맞다.
    /// 줄임표는 애플이 이 자리에 쓰는 기호다(메모·파일이 그렇다) — 이름 옆에 서므로
    /// 글자보다 기호가 낫다. 이름과 겨루지 않는다.
    private var moreButton: some View {
        Button { menuOpen = true } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .medium))
                .frame(width: 38, height: 38)
                .background(menuOpen || editing ? Theme.ink : Theme.grey4, in: Circle())
                .foregroundStyle(menuOpen || editing ? Theme.paper : Theme.grey1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("이 묶음 손보기")
        // **목록도 앱의 얼굴로 짓는다.** 시스템 메뉴는 글자체부터 남의 것이라
        // 그 순간만 다른 앱이 된다. 뜨는 자리(단추 옆)는 시스템에 맡기고
        // 안에 서는 것만 이쪽에서 그린다.
        .popover(isPresented: $menuOpen, arrowEdge: .top) {
            menuList
                .presentationCompactAdaptation(.popover)
                .presentationBackground(Theme.paper)
        }
    }

    /// 할 수 있는 일들. 자주 하는 것이 위, 되돌릴 수 없는 것이 맨 아래다.
    private var menuList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !words.isEmpty {
                menuRow("이 묶음 연습", symbol: "rectangle.stack") { onPractice(words) }
                menuDivider
                // 켜는 자리와 끄는 자리를 같게 둔다. 밖에 따로 세우지 않으므로
                // 여기서 켜고 여기서 끈다.
                menuRow(editing ? "지우기 마치기" : "낱말 지우기",
                        symbol: editing ? "checkmark" : "minus.circle") {
                    withAnimation(.snappy(duration: 0.18)) { editing.toggle() }
                }
            }
            if folder != nil {
                if !words.isEmpty { menuDivider }
                menuRow("이름 바꾸기", symbol: "pencil") { renaming = true }
                menuDivider
                menuRow("묶음 없애기", symbol: "trash", destructive: true) { removing = true }
            }
        }
        .frame(width: 208)
    }

    private var menuDivider: some View {
        Divider().overlay(Theme.grey4).padding(.horizontal, 14)
    }

    /// 목록 한 줄. 글이 왼쪽, 기호가 오른쪽 — 애플의 메뉴와 차례가 같다.
    private func menuRow(_ title: String, symbol: String, destructive: Bool = false,
                         action: @escaping () -> Void) -> some View {
        Button {
            // **누른 뒤에 목록이 닫힌다.** 열어 둔 채로 다음 화면을 띄우면
            // 판과 목록이 함께 떠 있는 순간이 생긴다.
            menuOpen = false
            action()
        } label: {
            HStack(spacing: 12) {
                Text(title)
                    .font(Theme.korean(15))
                Spacer(minLength: 8)
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(destructive ? Color.red : Theme.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 담긴 것이 없을 때. **자리는 있고 아직 아무것도 넣지 않았을 뿐이다** —
    /// 그렇게 보이게 적는다. 잘못 들어온 화면이 아니라는 것이 먼저다.
    ///
    /// 책장의 빈 화면처럼 가운데 세우지 않는다. 여기는 이름이 위에 서 있는 화면이라,
    /// 글이 이름 아래에서 이어져야 그 묶음에 대한 말로 읽힌다.
    private var emptyWords: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(folder == nil ? "아직 담은 것이 없어요" : "이 묶음은 아직 비어 있어요")
                .font(Theme.korean(17, weight: .medium))
                .foregroundStyle(Theme.grey1)
            Text(folder == nil
                 ? "찾기에서 낱말 옆의 갈피표를 누르면 여기 모입니다."
                 : "찾기에서 낱말 옆의 갈피표를 누르고 이 묶음을 고르면 여기 모입니다.")
                .font(Theme.korean(14))
                .foregroundStyle(Theme.grey2)
        }
        .padding(.horizontal, Theme.gutter)
    }

    /// 낱말 한 줄.
    ///
    /// 책장 목록에서는 알약으로 늘어놓아 소리만 훑게 했는데, 여기서는 **뜻까지 세운다** —
    /// 한 화 분량을 훑으려고 들어온 화면이라 무엇을 담았는지 읽혀야 한다.
    /// 층의 차례는 화면 어디서나 같다 — 가나 · 한글.
    private func row(_ word: CollectedWord) -> some View {
        Button { detail = word } label: {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(word.reading)
                            .font(Theme.japanese(21, weight: .medium))
                            .foregroundStyle(Theme.ink)
                        if let 품사 = word.partOfSpeech { PartOfSpeechTag(name: 품사) }
                    }
                }
                if !word.gloss.isEmpty {
                    Spacer(minLength: 12)
                    Text(word.gloss)
                        .font(Theme.korean(13))
                        .foregroundStyle(Theme.grey2)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("자세히 봅니다")
    }
}
