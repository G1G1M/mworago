import SwiftUI
import MworagoCore

/// 교재에서 낱말 하나를 펼쳐 본 것.
///
/// 전에는 낱말을 누르면 **찾기 탭으로 건너갔다.** 모아 둔 것을 다시 만나는 길을 내려던
/// 것인데, 대가가 있었다 — 교재에서 나가 버리니 여러 개를 훑을 때마다 돌아와야 하고,
/// 입력 바에 남아 있던 검색어가 덮여 원래 보던 것이 사라졌다.
///
/// **길을 없애는 것이 아니라 기본 동작을 바꾼다.** 누르면 여기서 펼치고,
/// 찾기로 가는 것은 버튼 하나로 남긴다.
///
/// 층의 차례는 화면 어디서나 같다 — **가나 · 한글**.
struct WordDetail: View {
    let word: CollectedWord
    /// 찾기로 건너간다. 없애지 않고 버튼 하나로 남겨 둔 길이다.
    var onFind: (String) -> Void = { _ in }
    /// 교재에서 뺀다.
    var onRemove: (CollectedWord) -> Void = { _ in }
    /// 다른 묶음으로 옮긴다. 담을 때는 묻지 않는 대신, 나중에 여기서 고쳐 넣는다.
    var onMove: (CollectedWord, String?) -> Void = { _, _ in }
    /// 고를 수 있는 묶음들.
    var folderNames: [String] = []

    @Environment(\.dismiss) private var dismiss
    /// 옮길 곳을 고르는 중인가.
    ///
    /// **묶음 화면에서 여럿을 옮기는 것과 같은 판을 쓴다.** 하나를 옮기든 셋을 옮기든
    /// 하는 일이 같은데 얼굴이 다르면 문법을 두 벌 배워야 한다. 담기(찾기에서 갈피표를
    /// 누르는 자리)만 시트로 남는다 — 그쪽은 낱말을 손에 들고 와서 **새 묶음을 만들며**
    /// 담는 자리라 목록이 길고, 판보다 시트가 맞다.
    @State private var moving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    layers
                    gloss
                    folderRow
                    collectedAt
                    actions
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 8)
                .padding(.bottom, Theme.screenBottom)
                .frame(maxWidth: Theme.readWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.paper)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                        .font(Theme.korean(16))
                        .foregroundStyle(Theme.ink)
                }
            }
        }
        .dialog(isPresented: $moving) {
            FolderChooserDialog(title: "어디로 옮길까요?",
                                hint: word.reading,
                                folderNames: folderNames,
                                // 점은 **지금 있는 자리**를 가리킨다.
                                current: word.folder,
                                isPresented: $moving) { onMove(word, $0) }
        }
    }

    /// 가나 · 한글. 카드와 문장이 쓰는 것과 같은 차례다.
    /// 여기서는 다이얼로 접지 않는다 — 펼쳐 보려고 연 화면이기 때문이다.
    ///
    /// **소리가 가장 큰 글자 곁에 선다.** 펼쳐 보려고 연 화면이라, 눈으로 볼 것과
    /// 귀로 들을 것이 같은 자리에 있어야 한다.
    private var layers: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(word.reading)
                    .font(Theme.japanese(34, weight: .medium))
                    .foregroundStyle(Theme.ink)
                if let 품사 = word.partOfSpeech { PartOfSpeechTag(name: 품사) }
                SpeakButton(text: word.reading, size: 18)
            }

            Text(word.hangul)
                .font(Theme.korean(15))
                .foregroundStyle(Theme.grey3)
        }
    }

    /// **담을 때 보였던 뜻**을 그대로 붙든다. 뜻이 나중에 좋아지더라도
    /// 무엇을 보고 담았는지가 그 사람의 기억과 맞다.
    @ViewBuilder
    private var gloss: some View {
        if !word.gloss.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("뜻")
                    .font(Theme.korean(12))
                    .foregroundStyle(Theme.grey3)
                Text(word.gloss)
                    .font(Theme.korean(17))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// 언제 걸렸는지. 날짜가 곧 그 화라서, 여기서도 한 번 말해 준다.
    private var collectedAt: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("담은 날")
                .font(Theme.korean(12))
                .foregroundStyle(Theme.grey3)
            Text(word.collectedAt, format: .dateTime.year().month(.wide).day().locale(Theme.locale))
                .font(Theme.korean(15))
                .foregroundStyle(Theme.grey1)
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().overlay(Theme.grey3)

            HStack(spacing: 10) {
                Button {
                    dismiss()
                    onFind(word.hangul)
                } label: {
                    Text("찾기에서 보기")
                        .font(Theme.korean(15))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Theme.ink, in: Capsule())
                        .foregroundStyle(Theme.paper)
                }
                .buttonStyle(.plain)

                Button {
                    onRemove(word)
                    dismiss()
                } label: {
                    Text("교재에서 빼기")
                        .font(Theme.korean(15))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Theme.grey4, in: Capsule())
                        .foregroundStyle(Theme.grey1)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// 어느 묶음에 든 낱말인가.
    ///
    /// 담을 때 이미 물었지만, 그때 고른 것이 늘 맞는 것은 아니다 — 하루에 두 편을 봤거나
    /// 지난번 골라져 있던 것을 그대로 눌렀을 수 있다. 여기가 고쳐 넣는 자리다.
    private var folderRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("묶음")
                .font(Theme.korean(12))
                .foregroundStyle(Theme.grey2)
            // **누르면 담기와 같은 모달이 열린다.** 메뉴였을 때는 이미 있는 묶음으로만
            // 옮길 수 있어서, 새 자리로 보내려면 먼저 딴 낱말을 담아 묶음을 만들어야 했다.
            Button { moving = true } label: {
                HStack(spacing: 6) {
                    Text(word.folder ?? "아직 안 넣음")
                        .font(Theme.korean(15))
                        .foregroundStyle(word.folder == nil ? Theme.grey3 : Theme.ink)
                    Text("옮기기")
                        .font(Theme.korean(12))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Theme.grey4, in: Capsule())
                        .foregroundStyle(Theme.grey1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
