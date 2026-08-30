import SwiftUI

/// 탭 넷.
///
/// 앱의 이야기가 이 차례다 — 걸린 대사를 **찾고**, 찾은 것이 **모이고**,
/// 모인 것이 그 화의 **교재**가 되고, 마지막에 **따라 말한다**.
/// 그래서 탭 순서가 곧 사용자가 겪는 순서다.
///
/// 탭바는 표준 컨트롤을 그대로 쓰고 색만 맞춘다. 직접 그리면 시스템이 주는 것
/// (아이패드의 자리, 손대기 좋은 크기, 손쉬운 사용)을 전부 다시 만들어야 한다.
struct RootView: View {
    @State private var collection = CollectionStore()
    /// 어느 탭을 열지 실행 인자로 고를 수 있다 (`--tab=collection`).
    /// `--query=` · `--select=` · `--aid=` 와 같은 취지 — 시뮬레이터를 손으로 두드리면
    /// 엉뚱한 것을 누르기 쉽고, 무엇을 눌렀는지도 기록에 남지 않는다.
    @State private var tab: RootTab = RootTab(argument: ProcessInfo.processInfo.arguments)

    enum RootTab: Hashable {
        case find, collection, book, practice

        init(argument arguments: [String]) {
            let name = arguments.first { $0.hasPrefix("--tab=") }
                .map { String($0.dropFirst("--tab=".count)) }
            switch name {
            case "collection": self = .collection
            case "book": self = .book
            case "practice": self = .practice
            default: self = .find
            }
        }
    }

    var body: some View {
        // iOS 18 부터의 `Tab` 을 쓴다. 예전 `.tabItem` 은 호환 경로로 가면서
        // 아이패드에서 탭바가 위아래로 **두 번** 그려졌다.
        TabView(selection: $tab) {
            Tab(value: RootTab.find) {
                SearchView(collection: collection)
            } label: {
                Label("찾기", systemImage: "magnifyingglass")
            }
            Tab(value: RootTab.collection) {
                CollectionView(collection: collection)
            } label: {
                Label("모은 것", systemImage: "bookmark")
            }
            Tab(value: RootTab.book) {
                NotYetView(
                    title: "도감",
                    line: "모은 낱말이 화별로 묶여 교재가 되는 자리입니다.",
                    detail: "지금은 낱말을 모으는 데까지 왔어요. 한 화 분량이 모이면 여기서 그 화를 통째로 복습하게 됩니다."
                )
            } label: {
                Label("도감", systemImage: "books.vertical")
            }
            Tab(value: RootTab.practice) {
                NotYetView(
                    title: "연습",
                    line: "따라 말하는 자리입니다.",
                    detail: "도감이 만들어지면, 그 대사를 소리 내어 따라 하고 얼마나 닮았는지 봅니다. 자막 없이 알아듣는 것이 목적지예요."
                )
            } label: {
                Label("연습", systemImage: "waveform")
            }
        }
        // **탭바를 아래에 둔다.** 아이패드의 상단 탭바는 시스템이 글자만 그려서
        // (애플 사진 앱의 보관함·모음도 그렇다) 무엇을 하는 자리인지 아이콘으로 알 수 없다.
        // 가로 사이즈 클래스를 compact 로 주면 아이폰과 같은 하단 아이콘 탭바가 된다.
        .environment(\.horizontalSizeClass, .compact)
        .tint(Theme.ink)
    }
}
