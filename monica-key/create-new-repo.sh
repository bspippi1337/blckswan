#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

TARGET="${TARGET:-bspippi1337/monica-key}"
SRC="${SRC:-$HOME/.cache/monica-key-source}"
OUT="${OUT:-$HOME/monica-key}"

pkg install -y git gh sed

gh auth status >/dev/null 2>&1 || {
  echo "Kjør først: gh auth login"
  exit 1
}

gh repo view "$TARGET" >/dev/null 2>&1 && {
  echo "$TARGET finnes allerede"
  exit 1
}

mkdir -p "$HOME/.cache"
if [[ -d "$SRC/.git" ]]; then
  git -C "$SRC" fetch origin agent/monica-key-live
  git -C "$SRC" reset --hard origin/agent/monica-key-live
else
  git clone --depth=50 --branch agent/monica-key-live \
    https://github.com/bspippi1337/blckswan.git "$SRC"
fi

cd "$SRC"
git branch -D monica-key-standalone 2>/dev/null || true
git subtree split --prefix=monica-key -b monica-key-standalone

[[ ! -e "$OUT" ]] || {
  echo "$OUT finnes allerede. Flytt eller slett den først."
  exit 1
}

git clone --branch monica-key-standalone "$SRC" "$OUT"
cd "$OUT"

git remote remove origin
mkdir -p .github/workflows
cp "$SRC/.github/workflows/monica-key.yml" .github/workflows/build.yml

sed -i \
  -e 's#agent/monica-key-live#main#g' \
  -e 's#monica-key/app/#app/#g' \
  -e 's#monica-key/server#server#g' \
  -e 's#-p monica-key ##g' \
  -e 's#monica-key/\*\*#app/**#g' \
  .github/workflows/build.yml

sed -i \
  -e 's#bspippi1337/blckswan#bspippi1337/monica-key#g' \
  -e 's#agent/monica-key-live#main#g' \
  -e 's#blckswan/monica-key#monica-key#g' \
  README.md github-build-termux.sh build-termux.sh

sed -i \
  -e 's#cd "$WORK/monica-key"#cd "$WORK"#g' \
  -e 's#monica-key.yml#build.yml#g' \
  github-build-termux.sh build-termux.sh

rm -f create-new-repo.sh create-standalone-repo.sh

git config user.name "Anders Pippi Tednes"
git config user.email "bspippi1337@gmail.com"
git add -A
git commit -m "Make Monica Key a standalone repository"

gh repo create "$TARGET" \
  --public \
  --description "Private native Android live location, timeline, ETA, encrypted chat and voice" \
  --source=. \
  --remote=origin \
  --push

gh workflow run build.yml --repo "$TARGET" --ref main || true

echo "https://github.com/$TARGET"
