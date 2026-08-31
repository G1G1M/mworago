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
/// **고르면 곧 담기고 닫힌다.** 확인 버튼을 따로 두면 탭이 하나 더 늘고, 그 버튼이
/// 하는 일도 방금 누른 것과 같다.
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

    @Environment(\.dismiss) private var dismiss

    /// 새 묶음 이름을 받는 중인가.
    ///
    /// **묶음이 하나도 없으면 펼친 채로 연다.** "폴더가 없으면 거기서 만든다"는 것이
    /// 이 모달의 절반인데, 빈 목록에 만들기 버튼 하나만 놓으면 그것을 한 번 더 누르게 한다.
    @State private var naming: Bool
    @State private var newName = ""
    @FocusState private var nameFocused: Bool

    init(word: CollectedWord, folderNames: [String], lastFolder: String?,
         onPick: @escaping (String?) -> Void,
         prompt: String = "어디에 담을까요?", markLabel: String = "지난번") {
        self.word = word
        self.folderNames = folderNames
        self.lastFolder = lastFolder
        self.onPick = onPick
        self.prompt = prompt
        self.markLabel = markLabel
        _naming = State(initialValue: folderNames.isEmpty)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                head
                ForEach(folderNames, id: \.self) { name in
                    row(name: name, picked: name == lastFolder) { pick(name) }
                }
                if !folderNames.isEmpty { line }
                newFolder
                line
                // 묶음을 정하지 않고 담는다. **첫 낱말을 담으려고 폴더부터 만들게 하지
                // 않는다.** 이렇게 담은 것은 책장의 "아직 안 넣은 것"으로 모이고,
                // 상세에서 나중에 옮길 수 있다 — 이름이 그것을 말해 준다.
                row(name: "나중에 정하기",
                    picked: lastFolder == nil && !folderNames.isEmpty,
                    dim: true) { pick(nil) }
            }
            .frame(maxWidth: Theme.readWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
            .padding(.bottom, Theme.screenBottom)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Theme.paper)
        .presentationDragIndicator(.visible)
        // **시트를 내용에 맞춘다.** 아이패드의 기본 폼 시트는 네댓 줄짜리 목록에
        // 화면 절반을 내주어, 고를 것이 셋인데 빈 자리가 그보다 넓어 보인다.
        // 아이폰은 `presentationSizing` 이 듣지 않으므로 detent 로 같은 일을 한다.
        .presentationSizing(.fitted)
        .presentationDetents([.medium, .large])
    }

    /// 무엇을 담는 중인지 말해 준다. 갈피표를 누른 뒤 모달이 뜨는 사이에 시선이
    /// 옮겨 가므로, 어느 낱말이었는지 여기서 한 번 더 짚어 준다.
    private var head: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(prompt)
                .font(Theme.korean(17))
                .foregroundStyle(Theme.ink)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(word.reading)
                    .font(Theme.japanese(15))
                    .foregroundStyle(Theme.grey1)
                if !word.gloss.isEmpty {
                    Text(word.gloss)
                        .font(Theme.korean(12))
                        .foregroundStyle(Theme.grey2)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    private var line: some View {
        Divider().overlay(Theme.grey4).padding(.vertical, 5)
    }

    /// 묶음 한 줄. 왼쪽 점이 **지난번에 넣은 곳**을 가리킨다.
    ///
    /// 고른 상태가 아니라 기억한 자리라서, 검게 채우되 크기는 작게 둔다 —
    /// 이 화면에서 검게 채워지는 것은 이것 하나뿐이다.
    private func row(name: String, picked: Bool, dim: Bool = false,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Circle()
                    .strokeBorder(picked ? Theme.ink : Theme.grey3, lineWidth: 1.5)
                    .background(Circle().fill(picked ? Theme.ink : .clear).padding(3.5))
                    .frame(width: 16, height: 16)
                Text(name)
                    .font(Theme.korean(16))
                    .foregroundStyle(dim ? Theme.grey1 : Theme.ink)
                Spacer(minLength: 10)
                if picked {
                    Text(markLabel)
                        .font(Theme.korean(11))
                        .foregroundStyle(Theme.grey2)
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(picked ? "\(markLabel) 자리입니다" : "")
    }

    /// 새 묶음. 접혀 있을 때는 한 줄, 펼치면 그 자리가 이름 받는 칸이 된다.
    ///
    /// **만들면 곧 담긴다.** 만들기와 담기를 나누면 빈 묶음이 생길 수 있고,
    /// 그러면 "이 묶음에 아무것도 없는데 왜 있지"를 사용자가 치워야 한다.
    @ViewBuilder
    private var newFolder: some View {
        if naming {
            VStack(alignment: .leading, spacing: 10) {
                TextField("예) 일상생활", text: $newName)
                    .font(Theme.korean(16))
                    .foregroundStyle(Theme.ink)
                    .textFieldStyle(.plain)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit { createAndPick() }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Theme.grey4, in: RoundedRectangle(cornerRadius: 10))

                HStack(spacing: 10) {
                    Button("만들어 담기") { createAndPick() }
                        .font(Theme.korean(15))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Theme.ink, in: Capsule())
                        .foregroundStyle(Theme.paper)
                        .buttonStyle(.plain)
                        .disabled(trimmedName.isEmpty)
                        .opacity(trimmedName.isEmpty ? 0.4 : 1)

                    if !folderNames.isEmpty {
                        Button("그만두기") {
                            naming = false
                            newName = ""
                        }
                        .font(Theme.korean(15))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Theme.grey4, in: Capsule())
                        .foregroundStyle(Theme.grey1)
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 10)
            .onAppear { nameFocused = true }
        } else {
            Button {
                naming = true
                nameFocused = true
            } label: {
                HStack(spacing: 11) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 16)
                    Text("새 묶음 만들기")
                        .font(Theme.korean(16))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(Theme.grey1)
                .padding(.horizontal, Theme.gutter)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var trimmedName: String {
        newName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func createAndPick() {
        guard !trimmedName.isEmpty else { return }
        pick(trimmedName)
    }

    private func pick(_ folder: String?) {
        onPick(folder)
        dismiss()
    }
}
