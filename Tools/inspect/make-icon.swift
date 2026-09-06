#!/usr/bin/env swift
// 앱 아이콘을 굽는다.
//
//   swift Tools/inspect/make-icon.swift
//
// 손으로 그린 그림 파일을 두는 대신 규칙을 코드로 둔다. 비율을 바꾸고 싶으면
// 아래 숫자를 고쳐 다시 구우면 되고, 무엇을 왜 그렇게 정했는지가 함께 남는다.
//
// **모양** — 히라가나 `あ` 와 그 아래 밑줄 하나.
//
// 앞의 것은 알약 셋이었다(붙여 친 한 줄을 사전이 끊어 주는 것, 頭 · が · 痛い 의 비율).
// 뜻은 맞았지만 **그 뜻이 보이려면 이 앱을 이미 알아야 했다** — 처음 보는 사람에게는
// 말줄임표나 로딩 표시로 읽힌다. 앱 목록에서 아이콘이 하는 일은 그것이 아니다.
//
// `あ` 는 오십음도의 첫 글자이자 일본어 입력기가 스스로를 가리킬 때 쓰는 글자라,
// **이것이 일본어를 다루는 앱이라는 것**을 한 글자로 말한다. 밑줄은 앞 아이콘의
// 조각 셋을 하나로 줄인 것이다 — 사전이 거기를 짚어 준다는 몸짓.
//
// 글꼴은 앱이 쓰는 Zen Maru Gothic 그대로다. 둥근 고딕이라 밑줄의 둥근 끝과 결이 맞는다.
//
// 색은 앱이 쓰는 한 벌 그대로다(Theme.ink · Theme.paper). **흰 바탕에 검은 알약**이라
// 앱을 열었을 때의 화면과 같은 색이 이어진다. 순백(1.0)이 아니라 종이색인 것은
// 화면 배경과 같은 값을 쓰기 위해서다.
//
// 흰 바탕은 밝은 배경화면 위에서 아이콘의 경계가 흐려진다 — iOS 는 테두리를
// 그려 주지 않는다. 굽고 나면 홈 화면에 놓고 보아야 한다.
import AppKit
import CoreText

let side: CGFloat = 1024

// 시안에서 정한 비율(아이콘 한 변을 1로 본 값)을 1024 로 옮긴다.
let glyphSize = (side * 0.52).rounded()      // 글자 크기
let ruleWidth = (side * 0.42).rounded()      // 밑줄 길이
let ruleHeight = (side * 0.055).rounded()    // 밑줄 굵기
let ruleGap = (side * 0.075).rounded()       // 글자 아래와 밑줄 사이


// **픽셀을 직접 잡고 CGContext 로 그린다.**
// NSImage(size:) 는 포인트 단위라 레티나에서 2048 로 구워졌고 알파도 붙었다 —
// iOS 앱 아이콘은 투명도를 허용하지 않는다(스토어가 되돌려보낸다).
// NSGraphicsContext 로 바꿨더니 이번에는 아무것도 그려지지 않고 검은 판만 남았다.
// 비트맵의 초기값이 0(검정)이라 "배경만 칠해졌다"고 착각하기 쉬운 자리다.
guard let cg = CGContext(data: nil, width: Int(side), height: Int(side),
                         bitsPerComponent: 8, bytesPerRow: 0,
                         space: CGColorSpaceCreateDeviceRGB(),
                         bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
else { fatalError("비트맵을 만들지 못했다") }

cg.setFillColor(red: 0.988, green: 0.988, blue: 0.973, alpha: 1)       // #FCFCFA · Theme.paper
cg.fill(CGRect(x: 0, y: 0, width: side, height: side))

let ink = CGColor(red: 0.09, green: 0.09, blue: 0.09, alpha: 1)        // #171717 · Theme.ink

// **글자와 밑줄을 한 덩어리로 보고 가운데 세운다.** 글자만 가운데 두면 밑줄만큼
// 아래가 무거워 보인다. 둘의 높이를 합쳐 그 덩어리를 가운데 놓는다.
//
// 글자의 실제 잉크 높이는 글꼴이 알려 주는 상자보다 작다(위아래 여백을 안고 있다).
// 그려 보고 재서 맞춰야 하므로 **글자가 차지한 자리를 먼저 잰다.**
// **글꼴은 파일에서 등록해 쓴다.** 앱이 싣는 그 파일이라야 화면과 아이콘의 `あ` 가
// 같은 글자가 된다 — 시스템에 깔린 다른 둥근 고딕을 집으면 미묘하게 다른 것이 구워진다.
let fontPath = "MworagoApp/Resources/Fonts/ZenMaruGothic-Medium.ttf"
guard FileManager.default.fileExists(atPath: fontPath) else {
    fatalError("글꼴이 없다 — ./Tools/fetch/fetch-fonts.sh 를 먼저 돌린다")
}
CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: fontPath) as CFURL, .process, nil)
let font = CTFontCreateWithName("ZenMaruGothic-Medium" as CFString, glyphSize, nil)

let line = CTLineCreateWithAttributedString(NSAttributedString(
    string: "あ", attributes: [.font: font, .foregroundColor: ink]))
let inkBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)

let blockHeight = inkBounds.height + ruleGap + ruleHeight
let blockBottom = ((side - blockHeight) / 2).rounded()

// 밑줄이 아래, 글자가 그 위. 좌우로는 둘 다 가운데다.
cg.setFillColor(ink)
let rule = CGRect(x: ((side - ruleWidth) / 2).rounded(), y: blockBottom,
                  width: ruleWidth, height: ruleHeight)
cg.addPath(CGPath(roundedRect: rule, cornerWidth: ruleHeight / 2, cornerHeight: ruleHeight / 2,
                  transform: nil))
cg.fillPath()

// `CTLineDraw` 는 기준선(baseline)에 그린다. 잉크 상자의 아래쪽이 우리가 놓고 싶은
// 자리이므로, 그만큼 기준선을 올려 잡는다.
cg.textPosition = CGPoint(x: ((side - inkBounds.width) / 2).rounded() - inkBounds.minX,
                          y: blockBottom + ruleHeight + ruleGap - inkBounds.minY)
CTLineDraw(line, cg)

let output = "MworagoApp/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
try? FileManager.default.createDirectory(atPath: (output as NSString).deletingLastPathComponent,
                                         withIntermediateDirectories: true)
guard let cgImage = cg.makeImage(),
      let png = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
else { fatalError("PNG 로 바꾸지 못했다") }
try png.write(to: URL(fileURLWithPath: output))
print("아이콘 완성 · \(Int(side))×\(Int(side)) · \(output)")
