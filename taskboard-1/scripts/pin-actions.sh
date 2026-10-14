#!/usr/bin/env bash
# Pins GitHub Actions to full commit SHAs (supply-chain protection: a tag can be moved, a SHA cannot).
#   scripts/pin-actions.sh          pin every `uses: owner/repo@vX # pin-sha`  (third-party SECURITY actions)
#   scripts/pin-actions.sh --all    pin every external action (also actions/*, aws-actions/*, ...)
# Needs network + git. Result: `uses: owner/repo@<40-char-sha> # vX`. Review the diff and commit it.
set -euo pipefail
cd "$(dirname "$0")/.."

mode="${1:-security}"
files=$(grep -rlE 'uses: [^./ ]+/[^ ]+@' .github || true)

for f in $files; do
  if [ "$mode" = "--all" ]; then
    pattern='uses: [A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+@v[0-9][^ ]*( #.*)?$'
  else
    pattern='uses: [A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+@v[0-9][^ ]* # pin-sha'
  fi
  grep -nE "$pattern" "$f" | while IFS=: read -r line _; do
    text=$(sed -n "${line}p" "$f")
    spec=$(echo "$text" | sed -E 's/.*uses: ([^ ]+).*/\1/')
    repo=${spec%@*}; tag=${spec#*@}
    owner_repo=$(echo "$repo" | cut -d/ -f1,2)
    # annotated tags: the commit is the ^{} entry
    sha=$(git ls-remote "https://github.com/${owner_repo}.git" "refs/tags/${tag}" "refs/tags/${tag}^{}" | tail -1 | cut -f1)
    if [ -z "$sha" ]; then echo "!! cannot resolve ${spec} (tag does not exist? fix the version in $f:$line)" >&2; continue; fi
    sed -i -E "${line}s|uses: ${repo//\//\\/}@${tag}.*|uses: ${repo}@${sha} # ${tag}|" "$f"
    echo "pinned ${repo}@${tag} -> ${sha}  ($f:$line)"
  done
done
