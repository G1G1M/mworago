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
    @State private var newName = ""
    @State private var removing = false

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    head
                    ForEach(words) { word in
                        row(word)
                        Divider().overlay(Theme.grey3)
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
        .alert("이름 바꾸기", isPresented: $renaming) {
            TextField(title, text: $newName)
            Button("바꾸기") {
                if let folder { onRename(folder, newName) }
                dismiss()   // 이름이 바뀌면 이 화면이 가리키던 묶음이 없다
            }
            Button("그만두기", role: .cancel) { }
        } message: {
            Text("이 묶음에 담긴 낱말이 다 따라갑니다.")
        }
        .alert("묶음을 없앨까요?", isPresented: $removing) {
            Button("없애기", role: .destructive) {
                if let folder { onRemoveFolder(folder) }
                dismiss()
            }
            Button("그만두기", role: .cancel) { }
        } message: {
            // 무엇이 남는지 먼저 말한다. 담은 것이 사라진다고 오해하면 누를 수 없다.
            Text("담은 낱말 \(words.count)개는 그대로 남고 '아직 안 넣은 것'으로 갑니다. 이름만 없어집니다.")
        }
    }

    /// 이름과 개수, 그리고 이 묶음에 할 수 있는 일.
    private var head: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text(title)
                    .font(Theme.korean(22, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("\(words.count)개")
                    .font(Theme.korean(13))
                    .foregroundStyle(Theme.grey3)
            }

            // 연습은 늘 있고, 이름을 손보는 일은 사용자가 지은 묶음에만 있다.
            HStack(spacing: 8) {
                Button { onPractice(words) } label: {
                    Text("이 묶음 연습")
                        .font(Theme.korean(13.5))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Theme.ink, in: Capsule())
                        .foregroundStyle(Theme.paper)
                }
                .buttonStyle(.plain)
                .accessibilityHint("이 묶음의 낱말만 연습합니다")

                if folder != nil {
                    Button {
                        newName = title
                        renaming = true
                    } label: {
                        Text("이름 바꾸기")
                            .font(Theme.korean(13.5))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Theme.grey4, in: Capsule())
                            .foregroundStyle(Theme.grey1)
                    }
                    .buttonStyle(.plain)

                    Button { removing = true } label: {
                        Text("묶음 없애기")
                            .font(Theme.korean(13.5))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Theme.grey4, in: Capsule())
                            .foregroundStyle(Theme.grey1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, Theme.screenTop)
        .padding(.bottom, Theme.blockGap)
    }

    /// 낱말 한 줄.
    ///
    /// 책장 목록에서는 알약으로 늘어놓아 소리만 훑게 했는데, 여기서는 **뜻까지 세운다** —
    /// 한 화 분량을 훑으려고 들어온 화면이라 무엇을 담았는지 읽혀야 한다.
    /// 층의 차례는 화면 어디서나 같다 — 가나 · 한자 · 한글.
    private func row(_ word: CollectedWord) -> some View {
        Button { detail = word } label: {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(word.reading)
                        .font(Theme.japanese(21, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    if word.headword != word.reading {
                        Text(word.headword)
                            .font(Theme.japanese(15))
                            .foregroundStyle(Theme.grey1)
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
