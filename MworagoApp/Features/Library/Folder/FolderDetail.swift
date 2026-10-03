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
    /// 이 묶음을 들고 연습으로 건너간다. 이름표에 적을 이름은 이 화면의 제목이다 —
    /// 묶음이면 묶음 이름, 날짜별로 열었으면 그날의 날짜다.
    var onPractice: ([CollectedWord], String) -> Void = { _, _ in }
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
    /// 고르는 손이 얹혔는가.
    ///
    /// **지우기만 되던 자리를 고르기로 넓혔다.** 담아 둔 것을 손보는 일은 지우는 것보다
    /// 옮기는 것이 잦은데(한 편을 몰아 담고 나서 갈래를 나눈다), 옮기기는 낱말 상세를
    /// 하나씩 열어야만 되는 일이었다. 골라 두고 한꺼번에 옮긴다.
    ///
    /// 미는 몸짓 대신 고르는 자리를 둔다 — 목록이 `LazyVStack` 이라 직접 만들면
    /// 훑는 손(세로)과 미는 손(가로)이 같은 자리에서 다툰다.
    @State private var selection = WordSelection()
    /// 고른 것을 어디로 옮길지 묻는 판.
    @State private var moving = false
    /// 고른 것을 지울지 묻는 자리. 되돌릴 수 없으므로 시스템 알림으로 묻는다.
    @State private var removingWords = false

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    head
                    if words.isEmpty { FolderEmptyState(isNamed: folder != nil) }
                    ForEach(words) { word in
                        HStack(spacing: 0) {
                            if selection.isActive { SelectionMark(isPicked: selection.contains(word.id)) }
                            FolderWordRow(word: word,
                                          selecting: selection.isActive,
                                          isPicked: selection.contains(word.id)) {
                                if selection.isActive { selection.toggle(word.id) } else { detail = word }
                            }
                        }
                        Theme.rule().padding(.horizontal, Theme.gutter)
                    }
                }
                .padding(.bottom, Theme.screenBottom)
                // 훑는 목록이지만 가나와 뜻이 **두 열로 갈린다.** 목록 폭(640)을 쓰면
                // 아이패드에서 두 열이 멀어져 한 줄을 눈으로 가로질러야 한다.
                .column()
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        // 줄임표 단추 밑에 뜨는 목록. 까닭은 `FolderMenuList` 에 적었다.
        .overlayPreferenceValue(FolderMenuAnchor.self) { anchor in
            menuOverlay(anchor)
        }
        // **제목은 화면 안에서 말한다.** 내비 바에도 두면 같은 이름이 두 번 나온다 —
        // 책장 루트에서 내비 바를 숨긴 것과 같은 까닭이다. 바는 뒤로 가는 길로만 쓴다.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // **목록째 넘긴다.** 이 묶음에 든 낱말들이 그대로 시트의 차례가 되어,
        // 펼쳐 본 자리에서 좌우로 밀면 이웃한 낱말이 온다.
        .sheet(item: $detail) { word in
            WordDetail(words: words,
                       start: word.id,
                       onFind: onFind,
                       onRemove: onRemoveWord,
                       onMove: { word, folder in
                           onMoveWord(word, folder)
                           // **옮기면 시트가 닫힌다.** 옮긴 낱말은 이 묶음에서 빠졌으니
                           // 여기 차례에도 없다 — 붙들고 있으면 목록에 없는 것을 목록의
                           // 한 자리인 척 보이게 된다. 닫히면서 그 줄이 사라진 목록이
                           // 드러나는 것이 옮겼다는 말을 가장 짧게 한다.
                           //
                           // 책장 `모두` 에서는 닫지 않는다 — 거기서는 묶음을 옮겨도
                           // 낱말이 목록에 그대로 남는다.
                           detail = nil
                       },
                       folderNames: folderNames)
        }
        // `--menu` 로 할 수 있는 일 목록을 펼친 채 띄운다. `--folder=` · `--detail` 과
        // 같은 취지 — 시뮬레이터는 손으로 두드릴 수 없어 이 목록을 눈으로 볼 길이 없다.
        .onAppear {
            guard !Self.openedFromArguments else { return }
            Self.openedFromArguments = true
            let launch = LaunchOptions.current
            if launch.has("menu") { menuOpen = true }
            // `--picking` 은 고르는 중(전부 고른 채)으로, `--moving` 은 그 위에
            // 옮기는 판까지 펼친 채로 띄운다.
            if launch.has("picking") || launch.has("moving") {
                selection.begin(picking: words.map(\.id))
                moving = launch.has("moving")
            }
        }
        // 책장의 "새 묶음"과 같은 판을 쓴다. 이름을 만드는 일과 고치는 일이
        // 다른 얼굴로 뜨면 같은 일을 두 번 배워야 한다.
        .dialog(isPresented: $renaming) {
            FolderNameDialog(title: "이름 바꾸기",
                             hint: "이 묶음에 담긴 낱말이 다 따라가요.",
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
        .wordSelectionActions(count: selection.count,
                              moving: $moving,
                              removing: $removingWords,
                              folderNames: folderNames,
                              current: folder,
                              onMove: moveSelected,
                              onRemove: removeSelected)
        // **지우는 것만 시스템 알림으로 묻는다.** 되돌릴 수 없는 일은 앱의 얼굴보다
        // 사용자가 이미 아는 "정말요?" 얼굴이 낫다.
        // 무엇이 남는지 먼저 말한다. 담은 것이 사라진다고 오해하면 누를 수 없다.
        // 빈 묶음에는 남을 낱말이 없으므로 그 말을 하지 않는다 — 없는 것을 세면
        // "낱말 0개는 그대로 남고" 처럼 읽을 수 없는 말이 된다.
        .confirmRemoval("묶음을 없앨까요?", isPresented: $removing, action: "없애기",
                        message: words.isEmpty
                            ? "담긴 낱말이 없어 이름만 없어져요."
                            : "담은 낱말 \(words.count)개는 그대로 남고 '아직 안 넣은 것'으로 가요. 이름만 없어져요.") {
            if let folder { onRemoveFolder(folder) }
            dismiss()
        }
    }

    /// 이름과 개수, 그리고 이 묶음에 할 수 있는 일.
    ///
    /// **고르는 중에는 이 줄이 통째로 바뀐다.** 떠 있는 바를 위에 얹었더니 묶음 이름을
    /// 가렸고, 가리지 않으려면 목록을 그만큼 밀어 내려야 했다. 고르기는 **모드**이므로
    /// 머리줄이 그 모드의 것으로 바뀌는 편이 맞다 — 무엇을 하는 중인지가 제자리에서 보인다.
    @ViewBuilder
    private var head: some View {
        if selection.isActive { selectionHead } else { titleHead }
    }

    private var titleHead: some View {
        VStack(alignment: .leading, spacing: 14) {
            // **이름과 할 일이 한 줄에 마주 선다.** 줄을 나눠 두면 이름 아래 캡슐이
            // 목록의 첫 줄처럼 읽혀서, 이 묶음에 하는 일인지 낱말에 하는 일인지 갈리지 않는다.
            // 이름은 왼쪽 끝, 할 일은 오른쪽 끝 — 그 사이가 비어 있어 둘이 다른 일임이 보인다.
            HStack(alignment: .center, spacing: 9) {
                // 이름과 개수는 서로 밑줄을 맞추고, 동그란 단추는 그 줄에 가운데로 선다.
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Text(title)
                        .font(Theme.korean(.heading, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    // 개수는 담긴 것이 있을 때만 적는다. `0개` 는 아래 안내가 이미 하는 말이고,
                    // 이름 옆에 붙으면 빈 자리를 세어 보라는 말처럼 읽힌다.
                    if !words.isEmpty {
                        Text("\(words.count)개")
                            .font(Theme.korean(.sub))
                            .foregroundStyle(Theme.grey3)
                    }
                }

                Spacer(minLength: 12)

                // **할 수 있는 일은 전부 이 안에 있다.**
                //
                // 연습만 밖에 캡슐로 세워 두었는데, 그러면 이름 옆에 크기가 다른 것이
                // 둘 서고 "이 묶음에 무엇을 할 수 있는지"가 두 자리로 갈린다.
                // 한 자리에서 열어 고르면 그 목록이 곧 답이다.
                if !words.isEmpty || folder != nil {
                    FolderMenuButton(isOpen: $menuOpen)
                }
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, Theme.screenTop)
        .padding(.bottom, Theme.blockGap)
    }

    /// 펼친 목록과, 바깥을 누르면 닫히는 바탕.
    ///
    /// 목록의 오른쪽 끝을 단추의 오른쪽 끝에 맞추고 단추 바로 밑에 둔다 — 팝오버가 서던 자리다.
    @ViewBuilder
    private func menuOverlay(_ anchor: Anchor<CGRect>?) -> some View {
        GeometryReader { proxy in
            if menuOpen, let anchor {
                let button = proxy[anchor]
                ZStack(alignment: .topLeading) {
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture { closeMenu() }
                    FolderMenuList(selecting: selection.isActive,
                                   hasWords: !words.isEmpty,
                                   isNamed: folder != nil,
                                   onClose: { closeMenu() },
                                   onPractice: { onPractice(words, title) },
                                   onToggleSelecting: {
                                       if selection.isActive {
                                           endSelecting()
                                       } else {
                                           withAnimation(.select) { selection.begin() }
                                       }
                                   },
                                   onRename: { renaming = true },
                                   onRemove: { removing = true })
                        .offset(x: button.maxX - FolderMenuList.width, y: button.maxY + 8)
                        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .topTrailing)))
                }
            }
        }
        .animation(.snappy(duration: 0.2), value: menuOpen)
    }

    private func closeMenu() {
        menuOpen = false
    }

    // MARK: 고르기

    private func endSelecting() {
        withAnimation(.select) { selection.end() }
    }

    /// 고른 것을 한꺼번에 옮긴다. **하나씩 옮기는 길과 같은 길을 쓴다** —
    /// 여기만 따로 저장하면 지난번 묶음을 건드리는지 같은 규칙이 두 벌이 된다.
    private func moveSelected(to destination: String?) {
        for word in selection.picked(in: words) { onMoveWord(word, destination) }
        endSelecting()
    }

    private func removeSelected() {
        for word in selection.picked(in: words) { onRemoveWord(word) }
        endSelecting()
    }

    /// 고르는 중의 머리줄. 책장 `모두` 목록과 **같은 것**을 쓴다 — `SelectionHead`.
    /// 이름 자리에 무엇을 고르는 중인지가 서고, 줄임표 자리에 그 낱말들로 할 수 있는 일이 선다.
    private var selectionHead: some View {
        SelectionHead(count: selection.count,
                      allPicked: selection.allPicked(of: words.map(\.id)),
                      onToggleAll: { selection.toggleAll(words.map(\.id)) },
                      onMove: { moving = true },
                      onRemove: { removingWords = true },
                      onDone: { endSelecting() })
            .padding(.horizontal, Theme.gutter)
            .padding(.top, Theme.screenTop)
            .padding(.bottom, Theme.blockGap)
    }
}
