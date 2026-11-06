#!/usr/bin/env bash
# Stáhne nové commity týmu, ať se práce nedělá dvakrát. Nic nemaže a nic nepřepisuje:
# fast-forward jen když to jde bez konfliktu s rozdělanou prací, jinak jen upozorní.
# Spouští ho hook SessionStart (.claude/settings.json) a ručně: bash scripts/git-sync.sh
cd "$(dirname "$0")/.." || exit 0
git fetch --quiet origin 2>/dev/null || { echo "git-sync: fetch selhal (offline?), pracuješ nad lokální verzí."; exit 0; }

branch=$(git rev-parse --abbrev-ref HEAD)
upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null) || { echo "git-sync: větev $branch nemá upstream."; exit 0; }
behind=$(git rev-list --count "HEAD..$upstream")
ahead=$(git rev-list --count "$upstream..HEAD")

if [ "$behind" -eq 0 ]; then
  [ "$ahead" -gt 0 ] && extra=" (napřed o $ahead, pushni)" || extra=""
  echo "git-sync: $branch je aktuální s $upstream$extra."
  exit 0
fi

if [ "$ahead" -eq 0 ] && git -c merge.autostash=false merge --ff-only --quiet "$upstream" 2>/dev/null; then
  echo "git-sync: staženo $behind nových commitů z $upstream:"
  git log --oneline -n "$behind" | sed 's/^/  /'
else
  echo "git-sync: POZOR – $branch je $behind commitů za $upstream a nejde to stáhnout automaticky (rozdělaná práce nebo vlastní commity)."
  echo "  Než začneš novou práci: commitni nebo odlož změny a spusť git pull --rebase."
  git log --oneline "HEAD..$upstream" | sed 's/^/  /'
fi
