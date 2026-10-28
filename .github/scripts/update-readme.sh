#!/usr/bin/env bash
# 重建 README 的「最近更新」区块：取公开、非 fork、未归档仓库中最近推送的前 5 个。
set -euo pipefail

OWNER="GzxingR"
README="README.md"
API="https://api.github.com/users/${OWNER}/repos?per_page=100&sort=pushed&type=owner"

json="$(curl -fsSL -H "Authorization: Bearer ${GH_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "${API}")"

block="$(printf '%s' "${json}" | jq -r --arg self "${OWNER}" '
  [ .[]
    | select(.fork == false and .archived == false and .private == false and .name != $self)
  ]
  | sort_by(.pushed_at) | reverse | .[0:5]
  | "| 仓库 | 说明 | 最近推送 |\n| :--- | :--- | :--- |",
    ( .[] | "| [\(.name)](\(.html_url)) | \(.description // "—") | \(.pushed_at[0:10]) |" )
')"

python3 - "$README" "$block" <<'PY'
import sys
path, block = sys.argv[1], sys.argv[2]
begin, end = "<!-- BEGIN:RECENT -->", "<!-- END:RECENT -->"
src = open(path, encoding="utf-8").read()
if begin not in src or end not in src:
    sys.exit("markers not found")
head, rest = src.split(begin, 1)
_, tail = rest.split(end, 1)
open(path, "w", encoding="utf-8", newline="\n").write(f"{head}{begin}\n{block}\n{end}{tail}")
PY

if git diff --quiet -- "${README}"; then
  echo "no change"
else
  git config user.name  "github-actions[bot]"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
  git add "${README}"
  git commit -m "chore: sync recent repositories"
  for attempt in 1 2 3; do
    git pull --rebase --autostash origin "${GITHUB_REF_NAME:-main}" && git push && exit 0
    echo "push attempt ${attempt} failed, retrying"
    sleep $((attempt * 3))
  done
  echo "push failed after retries" >&2
  exit 1
fi
