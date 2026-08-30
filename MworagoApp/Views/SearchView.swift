import SwiftUI
import MworagoCore

/// 읽기를 얼마나 보여줄지. 듀오링고가 발음 표시를 끄고 켜게 하듯,
/// 익숙해질수록 아래 층부터 끄는 다이얼이다.
enum ReadingAid: Int, CaseIterable, Identifiable {
    case hangul, kana, kanji

    var id: Int { rawValue }
    var label: String {
        switch self {
        case .hangul: "한글까지"
        case .kana: "가나까지"
        case .kanji: "한자만"
        }
    }
    var showsKana: Bool { self != .kanji }
    var showsHangul: Bool { self == .hangul }
}

struct SearchView: View {
    /// 한 줄이 지나치게 길어지면 눈이 되돌아올 곳을 잃는다. iPad 에서 특히 그렇다.
    private static let contentWidth: CGFloat = 640

    @State private var engine = SearchEngine()
    /// 실행 인자로 검색어를 넣을 수 있다 (`--query=다이죠부`).
    /// 시뮬레이터에 한글을 타이핑하지 않고도 화면을 확인할 수 있어 스크린샷과 점검에 쓴다.
    @State private var input = ProcessInfo.processInfo.arguments
        .first { $0.hasPrefix("--query=") }
        .map { String($0.dropFirst("--query=".count)) } ?? ""
    @State private var aid: ReadingAid = .hangul
    @FocusState private var inputFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.paper.ignoresSafeArea()

            results
            inputBar
        }
        .onAppear {
            if input.isEmpty { inputFocused = true } else { engine.search(input) }
        }
    }

    // MARK: 결과

    private var results: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if let failure = engine.failure {
                    notice("사전을 열지 못했습니다", detail: failure)
                } else if input.isEmpty {
                    emptyState
                } else if engine.segments.isEmpty {
                    notice("찾지 못했습니다", detail: "다르게 들렸을 수도 있어요. 한 글자만 바꿔 보세요.")
                } else {
                    ForEach(Array(engine.segments.enumerated()), id: \.offset) { _, segment in
                        SegmentCard(segment: segment, aid: aid)
                        Divider().foregroundStyle(Theme.grey3)
                    }
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 120)   // 입력 바에 가리지 않도록
            .frame(maxWidth: Self.contentWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("들린 대로 치세요")
                .font(Theme.korean(26, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("띄어 쓰지 않아도 됩니다. 어디서 끊을지는 사전이 정해요.")
                .font(Theme.korean(15))
                .foregroundStyle(Theme.grey2)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(["다이죠부", "아타마가이타이", "이타이야메로"], id: \.self) { example in
                    Button {
                        input = example
                        engine.search(example)
                    } label: {
                        HStack(spacing: 8) {
                            Text(example).font(Theme.korean(16))
                            Image(systemName: "arrow.up.left")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.grey3)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Theme.grey4, in: Capsule())
                        .foregroundStyle(Theme.grey1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 24)
        .padding(.top, 40)
    }

    private func notice(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(Theme.korean(19, weight: .medium)).foregroundStyle(Theme.ink)
            Text(detail).font(Theme.korean(14)).foregroundStyle(Theme.grey2)
        }
        .padding(.horizontal, 24)
        .padding(.top, 40)
    }

    // MARK: 입력 바 — 떠 있는 컨트롤에만 유리를 쓴다

    private var inputBar: some View {
        VStack(spacing: 10) {
            if !input.isEmpty { aidDial }

            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.grey2)
                TextField("다이죠부", text: $input)
                    .font(Theme.korean(19))
                    .foregroundStyle(Theme.ink)
                    .focused($inputFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: input) { _, new in engine.search(new) }
                if !input.isEmpty {
                    Button {
                        input = ""
                        engine.search("")
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.grey3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.grey3.opacity(0.5), lineWidth: 0.5)
            )
        }
        .frame(maxWidth: Self.contentWidth)
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    /// 강조는 반전 하나로만 — 고른 것이 검게 채워진다.
    private var aidDial: some View {
        HStack(spacing: 6) {
            ForEach(ReadingAid.allCases) { option in
                let selected = option == aid
                Button {
                    withAnimation(.snappy(duration: 0.18)) { aid = option }
                } label: {
                    Text(option.label)
                        .font(Theme.korean(13, weight: selected ? .semibold : .regular))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(selected ? Theme.ink : .clear, in: Capsule())
                        .foregroundStyle(selected ? Theme.paper : Theme.grey2)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 6)
    }
}
