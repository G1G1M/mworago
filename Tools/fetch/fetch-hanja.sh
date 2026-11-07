#!/bin/sh
# 한자의 한국 독음 표를 만든다. kanjidic2(EDRDG, CC BY-SA)에서 뽑는다.
#
# 앱에는 싣지 않는다. 화면에서 한자를 빼면서(이슈 #36) 이 표를 읽는 것은
# 뜻 감사(`swift run Translator --audit`)뿐이라, 도구 자료 자리에 둔다.
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
out = pathlib.Path("Tools/data/hanja-reading.tsv")
out.write_text("# 한자\t한국 독음 (kanjidic2, EDRDG, CC BY-SA)\n" +
               "".join(f"{c}\t{k}\n" for c, k in rows), encoding='utf-8')
print(f"한자 {len(rows)}자 · {out.stat().st_size // 1024}KB")
PY
