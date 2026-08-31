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
                Image(systemName: "magnifyingglass")
                    .accessibilityLabel("찾기")
            }
            Tab(value: RootTab.collection) {
                CollectionView(collection: collection)
            } label: {
                Image(systemName: "bookmark")
                    .accessibilityLabel("모은 것")
            }
            Tab(value: RootTab.book) {
                BookView(collection: collection)
            } label: {
                Image(systemName: "books.vertical")
                    .accessibilityLabel("도감")
            }
            Tab(value: RootTab.practice) {
                PracticeView(collection: collection)
            } label: {
                Image(systemName: "waveform")
                    .accessibilityLabel("연습")
            }
        }
        // 탭바에는 **아이콘만** 둔다. 넷뿐이고 뜻이 분명한 기호라 이름이 없어도 읽히고,
        // 글자가 빠지면 그만큼 화면이 조용해진다. 이름은 손쉬운 사용에 남겨 둔다 —
        // 눈으로 못 읽는 사람에게까지 아이콘만 주면 그건 지운 것이 아니라 잃은 것이다.
        //
        // **탭바를 아래에 둔다.** 아이패드의 상단 탭바는 시스템이 글자만 그려서
        // (애플 사진 앱의 보관함·모음도 그렇다) 무엇을 하는 자리인지 아이콘으로 알 수 없다.
        // 가로 사이즈 클래스를 compact 로 주면 아이폰과 같은 하단 아이콘 탭바가 된다.
        .environment(\.horizontalSizeClass, .compact)
        // **글은 전부 한국어다.** 기기 언어가 영어면 날짜만 "August 31"로 나와
        // 화면에서 그 한 줄만 남의 말이 된다. 이 앱이 쓰는 말로 고정한다.
        .environment(\.locale, Locale(identifier: "ko_KR"))
        .tint(Theme.ink)
    }
}
