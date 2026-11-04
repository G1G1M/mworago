#!/bin/sh
# 빌드 번호를 하나 올려 아카이브를 만들고 App Store Connect 로 올린다(TestFlight).
#
# Xcode 계정 대신 App Store Connect API 키로 서명하고 올린다. Xcode 27 에서는
# 설정 화면에 로그인되어 있어도 명령줄 내보내기가 계정을 찾지 못해
# 「Failed to Use Accounts」로 멈췄다. 키를 쓰면 배포 인증서도 클라우드 서명으로 받는다.
#
# 키 ID 와 발급자 ID 는 저장소에 두지 않는다. 환경 변수로 주거나
# Tools/release/asc.env(추적 안 함)에 적어 둔다:
#   ASC_KEY_ID=XXXXXXXXXX
#   ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
# 키 파일은 ~/.appstoreconnect/private_keys/AuthKey_<키 ID>.p8 에서 찾는다.
#
# 쓰는 법: ./Tools/release/testflight.sh            빌드 번호만 올린다
#          ./Tools/release/testflight.sh 1.2        마케팅 버전도 바꾼다
set -e
cd "$(dirname "$0")/../.."

[ -f Tools/release/asc.env ] && . ./Tools/release/asc.env
: "${ASC_KEY_ID:?ASC_KEY_ID 가 없다 — Tools/release/asc.env 를 확인한다}"
: "${ASC_ISSUER_ID:?ASC_ISSUER_ID 가 없다 — Tools/release/asc.env 를 확인한다}"
KEY_PATH="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8}"
[ -f "$KEY_PATH" ] || { echo "키 파일이 없다: $KEY_PATH" >&2; exit 1; }
[ -f MworagoApp/Resources/mworago-dict.db ] || { echo "사전 색인이 없다 — Tools/bake/setup-app-resources.sh 를 먼저 돌린다" >&2; exit 1; }

# 번호는 project.yml 이 정한다. Info.plist 는 xcodegen 이 그 값으로 다시 쓴다.
build=$(sed -n 's/^ *CFBundleVersion: "\([0-9]*\)"/\1/p' project.yml)
next=$((build + 1))
sed -i '' "s/^\( *CFBundleVersion: \)\"$build\"/\1\"$next\"/" project.yml
if [ -n "$1" ]; then
  sed -i '' "s/^\( *CFBundleShortVersionString: \)\"[^\"]*\"/\1\"$1\"/" project.yml
fi
version=$(sed -n 's/^ *CFBundleShortVersionString: "\(.*\)"/\1/p' project.yml)
xcodegen generate --quiet

out="$(mktemp -d)/mworago-$version-$next"
mkdir -p "$out"
auth="-allowProvisioningUpdates -authenticationKeyPath $KEY_PATH -authenticationKeyID $ASC_KEY_ID -authenticationKeyIssuerID $ASC_ISSUER_ID"

cat > "$out/export.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>app-store-connect</string>
<key>destination</key><string>upload</string>
<key>signingStyle</key><string>automatic</string>
<key>teamID</key><string>C5P7V9S6NT</string>
</dict></plist>
PLIST

echo "▶ $version ($next) 아카이브 — 기록: $out/archive.log"
# shellcheck disable=SC2086
xcodebuild archive -project Mworago.xcodeproj -scheme Mworago -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$out/Mworago.xcarchive" $auth \
  > "$out/archive.log" 2>&1 || { tail -n 30 "$out/archive.log"; exit 1; }

echo "▶ 올리기 — 기록: $out/upload.log"
# shellcheck disable=SC2086
xcodebuild -exportArchive -archivePath "$out/Mworago.xcarchive" \
  -exportOptionsPlist "$out/export.plist" -exportPath "$out/export" $auth \
  > "$out/upload.log" 2>&1 || { tail -n 30 "$out/upload.log"; exit 1; }

grep -q "Upload succeeded\|EXPORT SUCCEEDED" "$out/upload.log" || { tail -n 30 "$out/upload.log"; exit 1; }
echo "✔ $version ($next) 를 올렸다. 처리가 끝나면 TestFlight 에 뜬다(보통 10~30분)."
