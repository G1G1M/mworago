#!/bin/sh
# JESC(일영 자막 코퍼스)를 내려받는다. Stanford·Google Brain·Rakuten, CC BY-SA 4.0.
#
# 영화·TV 자막 279만 문장쌍. 구어체라는 것이 핵심이다.
# Tanaka Corpus 는 문어체 예문이라 てる 같은 구어 축약이 300문장에 1개뿐이었다.
#
# 자막에는 읽기가 없지만 JapaneseReading(CFStringTokenizer)이 만들어 준다.
# 그래서 이 코퍼스로 도메인 빈도를 직접 셀 수 있다 — JPDB 와 달리 재배포 조건이 분명하다.
set -e
cd "$(dirname "$0")/../.."
curl -L -o Tools/data/jesc-split.tar.gz "https://nlp.stanford.edu/projects/jesc/data/split.tar.gz"
tar -xzf Tools/data/jesc-split.tar.gz -C Tools/data/
ls -lh Tools/data/split/

echo
echo "빈도 목록을 만들려면:"
echo "  swift run SpikeRunner --build-frequency 3000000 > Tools/data/jesc_freq.tsv"
