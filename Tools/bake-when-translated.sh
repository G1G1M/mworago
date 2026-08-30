#!/bin/sh
# 번역이 끝나면 색인을 굽고 앱 리소스까지 갱신한다.
#
# 한국어 뜻 굽기는 2만 건에 열 시간쯤 걸린다. 끝나기를 사람이 지켜보고 있을 일이
# 아니라서, 끝나는 것을 기다렸다가 다음 세 단계를 이어 준다 —
# 색인 굽기 → 앱 리소스 복사 → (앱 빌드는 사람이 한다, 시뮬레이터를 고르는 일이라).
#
#   nohup ./Tools/bake-when-translated.sh > Tools/data/bake.log 2>&1 &
#
# 번역이 이미 끝나 있으면 곧바로 굽는다.
set -e
cd "$(dirname "$0")/.."
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:$PATH

while pgrep -f "debug/Translator" > /dev/null 2>&1; do
    sleep 60
done

echo "번역 끝남 · $(wc -l < Tools/data/korean-gloss.tsv)줄 · $(date '+%H:%M')"
./Tools/build-index.sh
cp Tools/data/mworago-dict.db MworagoApp/Resources/
echo "색인 갱신 완료 · $(date '+%H:%M')"
echo "남은 것: xcodegen generate && xcodebuild ... build"
