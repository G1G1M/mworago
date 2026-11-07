#!/bin/sh
# 한자의 한국 독음 표를 만든다. kanjidic2(EDRDG, CC BY-SA)에서 뽑는다.
#
# 쓸 만한 한일 사전이 없어 뜻이 영어로 남았다. 그 사이를 메우는 단서다.
# 約束→약속 처럼 뜻까지 통하는 것이 많고, 大丈夫→대장부 처럼 안 통해도 기억 고리가 된다.
set -e
cd "$(dirname "$0")/../.."
curl -L -o /tmp/kanjidic2.gz "http://ftp.edrdg.org/pub/Nihongo/kanjidic2.xml.gz"
gunzip -c /tmp/kanjidic2.gz > /tmp/kanjidic2.xml
python3 - <<'PY'
import re, pathlib
text = pathlib.Path('/tmp/kanjidic2.xml').read_text(encoding='utf-8')
rows = [(m.group(1), re.findall(r'<reading r_type="korean_h">([^<]+)</reading>', m.group(2)))
        for m in re.finditer(r'<character>\s*<literal>(.)</literal>(.*?)</character>', text, re.S)]
rows = [(c, k[0]) for c, k in rows if k]

# **kanjidic2 의 첫 독음이 일본 한자로는 틀린 글자**를 바로잡는다.
#
# 화면에 `大 대 · 変 변` 처럼 글자마다 독음을 보이므로, 틀린 독음은 그대로 틀린 것으로 보인다.
# 틀리는 길은 둘이다.
# - 신자체가 본디 따로 있던 다른 글자의 모양과 겹친다. 医 는 醫(의)를 줄인 것인데
#   kanjidic2 는 본디 글자 医(예)로 읽는다. 壊(壞 괴) · 担(擔 담) · 予(豫 예) 도 같다.
# - 독음이 여럿인데 덜 쓰는 쪽이 앞에 있다. 金 이 김 · 금 순이라 「김」으로 읽힌다.
# 일본어 낱말에서 그 글자가 거의 늘 읽히는 소리로 고른다.
FIX = {
    "医": "의", "壊": "괴", "担": "담", "胆": "담", "予": "예", "台": "대", "缶": "관",
    "欠": "결", "唇": "순", "芸": "예", "蚕": "잠", "虫": "충", "属": "속", "芦": "로",
    "斉": "제", "収": "수",
    "金": "금", "底": "저", "索": "색", "則": "칙", "状": "상", "参": "참", "降": "강",
    "不": "불", "乾": "건", "跳": "도", "奈": "나", "帥": "수", "曝": "폭", "倭": "왜",
}
known = {c for c, _ in rows}
rows = [(c, FIX.get(c, k)) for c, k in rows] + [(c, k) for c, k in FIX.items() if c not in known]
out = pathlib.Path("MworagoApp/Resources/hanja-reading.tsv")
out.write_text("# 한자\t한국 독음 (kanjidic2, EDRDG, CC BY-SA)\n" +
               "".join(f"{c}\t{k}\n" for c, k in rows), encoding='utf-8')
print(f"한자 {len(rows)}자 · {out.stat().st_size // 1024}KB")
PY
