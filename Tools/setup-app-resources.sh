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
# 빈도는 전량을 센 뒤 여기서 자른다. count>=5 인 것만 싣는다 —
# 한두 번 나온 낱말은 대부분 토크나이저가 잘못 읽은 것이라 도움이 아니라 방해였다.
# 재어 보니 어휘가 112,317 에서 53,775 로 절반이 되는데 분절 완전일치는 30.0%에서
# 30.3%로 오히려 올랐고, 낱말 검색은 그대로였다(3위 안 147/150).
[ -f Tools/data/jesc_freq.tsv ] || swift run SpikeRunner --build-frequency 3000000 \
  | awk -F'\t' 'NR==1 || $4>=5' > Tools/data/jesc_freq.tsv

[ -d MworagoApp/Resources/Fonts ] || ./Tools/fetch-fonts.sh
[ -f MworagoApp/Resources/hanja-reading.tsv ] || ./Tools/fetch-hanja.sh

mkdir -p MworagoApp/Resources
cp Tools/data/mworago-dict.db MworagoApp/Resources/
cp Tools/data/jesc_freq.tsv MworagoApp/Resources/
ls -lh MworagoApp/Resources/

echo
echo "이제 프로젝트를 만들고 열면 된다:"
echo "  xcodegen generate && open Mworago.xcodeproj"
