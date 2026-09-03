#!/bin/sh
# Tanaka Corpus(예문 모음)를 내려받는다. EDRDG 배포, CC BY-SA 4.0.
#
# 문장마다 사람이 손으로 나눈 낱말 경계와 읽기가 붙어 있다.
#   A: 彼は本を読む。
#   B: 彼(かれ)[01] は 本(ほん) を 読む
# 분절 정답을 내가 지어내지 않아도 되는 이유다.
set -e
cd "$(dirname "$0")/../.."
curl -L -o Tools/data/examples.utf.gz "http://ftp.edrdg.org/pub/Nihongo/examples.utf.gz"
gunzip -kf Tools/data/examples.utf.gz
ls -lh Tools/data/examples.utf
