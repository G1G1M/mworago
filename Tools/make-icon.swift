#!/usr/bin/env swift
// 앱 아이콘을 굽는다.
//
//   swift Tools/make-icon.swift
//
// 손으로 그린 그림 파일을 두는 대신 규칙을 코드로 둔다. 비율을 바꾸고 싶으면
// 아래 숫자를 고쳐 다시 구우면 되고, 무엇을 왜 그렇게 정했는지가 함께 남는다.
//
// **모양** — 붙여 친 한 줄을 사전이 낱말로 끊어 주는 것. 이 앱의 기술이 실제로 하는
// 일을 그대로 옮겼다. 조각 셋의 비율은 頭 · が · 痛い 에서 왔다 —
// 긴 낱말, 짧은 조사, 그 사이의 낱말. 글자가 없어 어느 나라 말로도 읽히지 않고,
// 홈 화면에서 40px 로 줄어도 세 덩어리가 셋으로 남는다.
//
// 색은 앱이 쓰는 한 벌 그대로다(Theme.ink · Theme.paper).
import AppKit

let side: CGFloat = 1024

// 시안에서 정한 비율(180pt 기준)을 1024 로 옮긴다.
let scale = side / 180
let barHeight = (22 * scale).rounded()
let gap = (9 * scale).rounded()
let widths = [22, 46, 30].map { ($0 * scale).rounded() }   // 頭 · が · 痛い


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

cg.setFillColor(red: 0.09, green: 0.09, blue: 0.09, alpha: 1)          // #171717 · Theme.ink
cg.fill(CGRect(x: 0, y: 0, width: side, height: side))

let totalWidth = widths.reduce(0, +) + gap * CGFloat(widths.count - 1)
var x = ((side - totalWidth) / 2).rounded()
let y = ((side - barHeight) / 2).rounded()

cg.setFillColor(red: 0.988, green: 0.988, blue: 0.973, alpha: 1)       // #FCFCFA · Theme.paper
for width in widths {
    // 끝이 완전히 둥근 알약. 화면의 다이얼·꼬리표와 같은 결이다.
    let bar = CGRect(x: x, y: y, width: width, height: barHeight)
    cg.addPath(CGPath(roundedRect: bar, cornerWidth: barHeight / 2, cornerHeight: barHeight / 2,
                      transform: nil))
    cg.fillPath()
    x += width + gap
}

let output = "MworagoApp/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
try? FileManager.default.createDirectory(atPath: (output as NSString).deletingLastPathComponent,
                                         withIntermediateDirectories: true)
guard let cgImage = cg.makeImage(),
      let png = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
else { fatalError("PNG 로 바꾸지 못했다") }
try png.write(to: URL(fileURLWithPath: output))
print("아이콘 완성 · \(Int(side))×\(Int(side)) · \(output)")
