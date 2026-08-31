import SwiftUI
import MworagoCore

/// 연습 — 모은 낱말을 한글 음차만 보고 떠올려 본다.
///
/// 기획의 목적지는 쉐도잉(소리 내어 따라 하고 얼마나 닮았는지 보기)이고 그것은 v2.0 이다.
/// 지금 가진 재료로 할 수 있는 것은 **모은 것을 다시 만나는 일**이다 —
/// 한글 음차를 먼저 보이고, 떠올린 다음 뒤집어 확인한다.
///
/// 채점하지 않는다. 맞혔는지 틀렸는지 기록하기 시작하면 점수를 관리하는 앱이 되는데,
/// 여기서 하려는 일은 **다시 마주치게 하는 것**뿐이다.
struct PracticeView: View {
    let collection: CollectionStore
    /// 교재에서 하루치만 들고 건너왔을 때 그 낱말들. 비어 있으면 모은 것 전체를 훑는다.
    ///
    /// **늘 전체를 훑으면 오늘 본 것을 다시 만나기까지 한참이 걸린다.** 스무 날치가
    /// 쌓인 뒤에는 더 그렇다. 어느 화를 복습할지는 사용자가 교재에서 고른다.
    var subset: [CollectedWord]? = nil
    var subsetLabel: String? = nil
    /// 하루치에서 빠져나와 전체로 돌아간다.
    var onClearSubset: () -> Void = {}

    @State private var index = 0
    @State private var revealed = false

    private var words: [CollectedWord] { subset ?? collection.words }
    private var current: CollectedWord? {
        words.indices.contains(index) ? words[index] : words.first
    }

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            if let word = current { card(word) } else { empty }
            if let subsetLabel { subsetBanner(subsetLabel) }
        }
        // 하루치를 새로 골라 오면 처음 낱말부터 시작한다.
        .onChange(of: subsetLabel) { _, _ in
            index = 0
            revealed = false
        }
    }

    /// 지금 무엇을 연습하고 있는지. 전체가 아니라면 그 사실이 화면에 있어야 한다 —
    /// 몇 장 넘기다 보면 어디서 온 묶음인지 잊는다.
    private func subsetBanner(_ label: String) -> some View {
        VStack {
            HStack(spacing: 10) {
                Text(label)
                    .font(Theme.korean(13, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text("\(words.count)개")
                    .font(Theme.korean(13))
                    .foregroundStyle(Theme.grey2)
                Button(action: onClearSubset) {
                    Text("전체")
                        .font(Theme.korean(13))
                        .foregroundStyle(Theme.grey2)
                }
                .buttonStyle(.plain)
                .accessibilityHint("모은 낱말 전체를 연습합니다")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.grey3.opacity(0.5), lineWidth: 0.5))
            .padding(.top, 14)
            Spacer()
        }
    }

    private func card(_ word: CollectedWord) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("연습")
                    .font(Theme.korean(24, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("\(min(index + 1, words.count)) / \(words.count)")
                    .font(Theme.korean(15))
                    .foregroundStyle(Theme.grey2)
            }
            .padding(.bottom, 40)

            // 소리부터 보인다. 이 앱에 온 사람은 소리를 듣고 왔다.
            Text(word.hangul)
                .font(Theme.korean(30, weight: .semibold))
                .foregroundStyle(Theme.ink)

            // 뒤집기 전에는 자리만 잡아 둔다. 답이 나타나며 아래가 밀리면
            // 눈이 따라가야 해서, 있던 자리에 그대로 나타나게 한다.
            VStack(alignment: .leading, spacing: 7) {
                Text(word.reading)
                    .font(Theme.japanese(34, weight: .medium))
                    .foregroundStyle(Theme.ink)
                if word.headword != word.reading {
                    Text(word.headword)
                        .font(Theme.japanese(21))
                        .foregroundStyle(Theme.grey1)
                }
                if !word.gloss.isEmpty {
                    Text(word.gloss)
                        .font(Theme.korean(15))
                        .foregroundStyle(Theme.grey1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 130, alignment: .top)
            .opacity(revealed ? 1 : 0)
            .padding(.top, 22)

            HStack(spacing: 10) {
                button(revealed ? "다시 덮기" : "뒤집기", filled: !revealed) {
                    withAnimation(.snappy(duration: 0.18)) { revealed.toggle() }
                }
                button("다음", filled: revealed) { next() }
            }
            .padding(.top, 26)
        }
        .frame(maxWidth: 460, alignment: .leading)
        .padding(.horizontal, 28)
    }

    /// 강조는 반전 하나로만 — 지금 눌러야 하는 것이 채워진다.
    private func button(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.korean(15, weight: filled ? .semibold : .regular))
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(filled ? Theme.ink : Theme.grey4, in: Capsule())
                .foregroundStyle(filled ? Theme.paper : Theme.grey1)
        }
        .buttonStyle(.plain)
    }

    private func next() {
        withAnimation(.snappy(duration: 0.18)) {
            revealed = false
            index = words.isEmpty ? 0 : (index + 1) % words.count
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("연습할 것이 없어요")
                .font(Theme.korean(22, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("모은 낱말을 한글만 보고 떠올려 보는 자리입니다.")
                .font(Theme.korean(15))
                .foregroundStyle(Theme.grey2)
            Text("소리 내어 따라 하고 얼마나 닮았는지 보는 것은 그다음이에요.")
                .font(Theme.korean(13))
                .foregroundStyle(Theme.grey3)
        }
        .frame(maxWidth: 460, alignment: .leading)
        .padding(.horizontal, 28)
    }
}
