#!/bin/sh
# 화면에 쓰는 폰트를 내려받는다. 둘 다 Google Fonts, SIL Open Font License.
#
#   Zen Maru Gothic  일본어 둥근 고딕. 가나가 화면의 얼굴이라 인상을 좌우한다
#   고운돋움          한글. 굵기가 하나뿐이라 위계는 크기와 색으로 만든다
set -e
cd "$(dirname "$0")/../.."
mkdir -p MworagoApp/Resources/Fonts
BASE="https://raw.githubusercontent.com/google/fonts/main/ofl"
for f in zenmarugothic/ZenMaruGothic-Regular.ttf \
         zenmarugothic/ZenMaruGothic-Medium.ttf \
         gowundodum/GowunDodum-Regular.ttf; do
  curl -fL -o "MworagoApp/Resources/Fonts/$(basename "$f")" "$BASE/$f"
done
ls -lh MworagoApp/Resources/Fonts/
