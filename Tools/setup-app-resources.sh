#!/bin/sh
# 앱이 실을 자료를 구워서 번들 폴더에 넣는다.
#
# 색인과 빈도 목록은 원본에서 만들어 내는 것이라 레포에 두지 않는다.
# 처음 받은 사람은 이 스크립트 하나만 돌리면 된다.
set -e
cd "$(dirname "$0")/.."

[ -f Tools/data/JMdict_e ]   || ./Tools/fetch-jmdict.sh
[ -f Tools/data/split/train ] || ./Tools/fetch-jesc.sh
[ -f Tools/data/mworago-dict.db ] || ./Tools/build-index.sh
[ -f Tools/data/jesc_freq.tsv ] || swift run SpikeRunner --build-frequency 3000000 > Tools/data/jesc_freq.tsv

mkdir -p MworagoApp/Resources
cp Tools/data/mworago-dict.db MworagoApp/Resources/
cp Tools/data/jesc_freq.tsv MworagoApp/Resources/
ls -lh MworagoApp/Resources/

echo
echo "이제 프로젝트를 만들고 열면 된다:"
echo "  xcodegen generate && open Mworago.xcodeproj"
