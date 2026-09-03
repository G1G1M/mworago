#!/usr/bin/env swift
// 스크린샷에서 **글자가 있는 가로줄만** 뽑는다.
//
// 왜 있느냐: 시뮬레이터 스크린샷을 눈으로 읽으면 없는 글자를 본다. 2420px 짜리
// 그림이 화면에 2000px 로 줄어 들어오는데, 그 축소본에서 화면 **위쪽 끝의 글자가
// 아래쪽 끝에 한 번 더 있는 것처럼** 읽히는 일을 한 자리에서 두 번 겪었다
// ("건너뛰기가 위아래로 두 번 그려진다"는 보고가 그렇게 났고, 재현하러 들어간
// 사람이 같은 착시를 두 번 더 했다). `Page.opticalLeading` 값을 픽셀로 재서 넣는
// 것과 같은 취지다 — 눈대중으로 못 가르는 것은 재서 가른다.
//
// 쓰는 법:
//   swift Tools/ink-rows.swift <스크린샷.png> [xMin] [xMax]
//
// 오른쪽 끝에 선 것(건너뛰기·다음)만 보려면 x 범위를 좁힌다:
//   swift Tools/ink-rows.swift shot.png 1150 1668
//
// 나오는 것: 어두운 픽셀이 이어진 가로줄 구간. 같은 글자가 두 번 그려졌다면
// 같은 높이의 구간이 두 번 나온다. 한 번만 나오면 한 벌이다.
import AppKit

let args = CommandLine.arguments
guard args.count >= 2,
      let image = NSImage(contentsOfFile: args[1]),
      let bitmap = image.representations.first as? NSBitmapImageRep else {
    print("쓰는 법: swift Tools/ink-rows.swift <스크린샷.png> [xMin] [xMax]")
    exit(1)
}

let width = bitmap.pixelsWide, height = bitmap.pixelsHigh
let xMin = args.count > 2 ? (Int(args[2]) ?? 0) : 0
let xMax = min(args.count > 3 ? (Int(args[3]) ?? width) : width, width)
print("\(width)x\(height) · x \(xMin)..<\(xMax)")

/// 바탕(크림색)보다 확실히 어두운 것만 글자로 센다. 얇은 구분선과 홈 인디케이터도
/// 걸리지만, 그것들은 높이 1~3px 이라 글자 구간과 눈에 띄게 다르다.
let inkThreshold: CGFloat = 0.62
/// 한 줄에 이만큼은 어두워야 글자로 친다. 안티에일리어싱 한두 점을 거른다.
let minimumInk = 2

var runs: [(from: Int, to: Int, peak: Int)] = []
var start = -1, peak = 0
for y in 0..<height {
    var ink = 0
    for x in xMin..<xMax where (bitmap.colorAt(x: x, y: y)?.brightnessComponent ?? 1) < inkThreshold {
        ink += 1
    }
    if ink > minimumInk {
        if start < 0 { start = y; peak = ink } else { peak = max(peak, ink) }
    } else if start >= 0 {
        runs.append((start, y - 1, peak)); start = -1; peak = 0
    }
}
if start >= 0 { runs.append((start, height - 1, peak)) }

for run in runs {
    print("y \(run.from)~\(run.to)  높이 \(run.to - run.from + 1)  가장 진한 줄 \(run.peak)px")
}
