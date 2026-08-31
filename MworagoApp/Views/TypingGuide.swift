import SwiftUI

/// 한글을 어떻게 치면 되는지 알려 주는 쪽지.
///
/// 화면에 늘 펼쳐 두지 않는다. "들린 대로 치세요"라는 한 문장이 이 앱이 하는 말의 전부인데,
/// 그 옆에 규칙 여섯 줄을 붙이면 그 문장이 흐려진다. 궁금해진 사람만 ⓘ 를 눌러 연다.
///
/// **적힌 것은 전부 실제로 재 본 것이다.** 규칙을 짐작해서 적으면, 있지도 않은 제약을
/// 가르치거나 정작 걸리는 자리를 빠뜨린다. 여기 예로 든 낱말은 모두 `SpikeRunner --explain`
/// 으로 확인했다.
struct TypingGuide: View {
    @Environment(\.dismiss) private var dismiss

    /// `--credits` 로 출처 화면을 펼친 채 띄울 수 있다.
    /// `--guide` 와 같은 뜻이다 — 시뮬레이터를 손으로 두드리지 않고 화면을 확인하려고.
    @State private var showingCredits = ProcessInfo.processInfo.arguments.contains("--credits")

    /// 한 줄. 왼쪽이 무엇에 대한 이야기인지, 오른쪽이 실제로 쳐 본 것이다.
    private struct Rule: Identifiable {
        let id = UUID()
        let name: String
        let examples: [Example]
        var note: String? = nil
    }

    /// 쳐 본 것들과 그래서 나온 것.
    ///
    /// 같은 곳에 닿는 표기는 **한 줄에 나란히** 둔다. 줄을 나누면 "둘 다 된다"가
    /// 눈에 안 보이고, 두 개의 다른 규칙처럼 읽힌다. 갈라지는 것만 줄을 나눈다.
    private struct Example: Identifiable {
        let id = UUID()
        let typed: [String]
        let result: String

        init(_ typed: String..., result: String) {
            self.typed = typed
            self.result = result
        }
    }

    /// 신경 쓰지 않아도 되는 것 — 어느 쪽으로 쳐도 같은 곳에 닿는다.
    private static let forgiving: [Rule] = [
        Rule(name: "길게 끄는 소리",
             examples: [.init("아리가토", "아리가토우", result: "有難う")]),
        Rule(name: "받침 ㄴ · ㅁ · ㅇ",
             examples: [.init("센빠이", "셈빠이", result: "先輩")]),
        Rule(name: "작은 っ 은 ㅅ 받침으로",
             examples: [.init("잇쇼", result: "一緒")]),
        Rule(name: "죠 · 쥬 · 쟈 를 조 · 주 · 자 로 적어도",
             examples: [.init("쇼죠", "쇼조", result: "少女")]),
        Rule(name: "つ 는 츠로도 쓰로도",
             examples: [.init("츠쿠에", "쓰쿠에", result: "机")]),
    ]

    /// 가려 적어야 하는 것.
    ///
    /// 여기서 어긋나면 "못 찾았습니다"가 아니라 **엉뚱한 낱말이 나온다.** 그래서 더 헷갈린다 —
    /// 답이 나왔으니 맞게 친 줄 알게 된다. 그것을 나란히 놓아 보이는 것이 이 칸의 일이다.
    ///
    /// **한때 셋이었다.** 요음(쇼죠 · 쇼조)과 つ(츠쿠에 · 쓰쿠에)는 후보 생성이 흡수해서
    /// 위 칸으로 옮겼다. 설명해야 할 제약을 줄이는 편이 설명을 잘 쓰는 것보다 낫다 —
    /// 짧은 도움말이 읽히는 도움말이다.
    private static let careful: [Rule] = [
        Rule(name: "탁음",
             examples: [.init("갓코", result: "学校"),
                        .init("캇코", result: "格好")],
             note: "들리는 대로 다 · 타를 가른다"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    Text("들린 대로 치면 됩니다. 정확히 옮길 필요는 없어요.")
                        .font(Theme.korean(16))
                        .foregroundStyle(Theme.grey1)
                        .padding(.top, 4)

                    section("신경 쓰지 않아도 되는 것", rules: Self.forgiving)
                    section("가려 적어야 하는 것", rules: Self.careful)

                    // 출처 표시는 자료의 라이선스가 요구하는 것이라 어디엔가 반드시 있어야 한다.
                    // 탭을 하나 더 늘리기보다, 이미 늘 닿는 이 쪽지 안에 둔다.
                    NavigationLink(value: "credits") {
                        HStack {
                            Text("이 앱이 쓰는 자료")
                                .font(Theme.korean(15))
                                .foregroundStyle(Theme.grey1)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.grey3)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .frame(maxWidth: 520, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.paper)
            .navigationDestination(for: String.self) { _ in Credits() }
            .navigationDestination(isPresented: $showingCredits) { Credits() }
            .navigationTitle("한글로 어떻게 치나")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                        .font(Theme.korean(16))
                        .foregroundStyle(Theme.ink)
                }
            }
        }
    }

    /// 한 갈래.
    ///
    /// 섹션 이름은 **작은 라벨**로 물러나고 그 아래 얇은 선이 갈래를 가른다.
    /// 이름을 본문만큼 키우면 규칙 이름과 섞여서, 무엇이 묶음이고 무엇이 항목인지
    /// 눈이 매번 다시 판단해야 한다.
    private func section(_ title: String, rules: [Rule]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(Theme.korean(12))
                    .tracking(0.6)
                    .foregroundStyle(Theme.grey2)
                Rectangle()
                    .fill(Theme.grey3)
                    .frame(height: 0.5)
            }

            // **섹션 하나를 통째로 격자에 세운다.** 규칙마다 격자를 따로 만들면 그 안에서만
            // 열이 맞아서, 화살표가 규칙을 건널 때마다 다른 자리에 놓인다. 같은 것을
            // 견주려는 눈이 매번 다시 찾는 것이 그 때문이다.
            // 규칙 이름과 덧말은 세 칸을 다 차지해 격자를 가로지른다.
            Grid(alignment: .leadingFirstTextBaseline,
                 horizontalSpacing: 12, verticalSpacing: 7) {
                ForEach(Array(rules.enumerated()), id: \.element.id) { index, rule in
                    GridRow {
                        Text(rule.name)
                            .font(Theme.korean(15))
                            .foregroundStyle(Theme.ink)
                            .padding(.top, index == 0 ? 0 : 11)
                            .gridCellColumns(3)
                    }
                    ForEach(rule.examples) { example in
                        GridRow {
                            Text(example.typed.joined(separator: " · "))
                                .font(Theme.korean(15))
                                .foregroundStyle(Theme.grey1)
                                .gridColumnAlignment(.trailing)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.grey3)
                            Text(example.result)
                                .font(Theme.japanese(16))
                                .foregroundStyle(Theme.ink)
                                .gridColumnAlignment(.leading)
                        }
                    }
                    if let note = rule.note {
                        GridRow {
                            Text(note)
                                .font(Theme.korean(13))
                                .foregroundStyle(Theme.grey2)
                                .gridCellColumns(3)
                        }
                    }
                }
            }
        }
    }
}
