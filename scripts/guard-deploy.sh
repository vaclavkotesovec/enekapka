#!/usr/bin/env bash
# PreToolUse hook (Bash): zastaví deploy, který by ve sdíleném orgu přepsal cizí práci.
# - deploy celého force-app (nebo force-app/main/default) bez výběru souborů,
# - deploy z větve, která je pozadu za origin (chybí v ní kód ostatních).
# Exit 2 = Claude Code příkaz zablokuje a ukáže důvod.
input=$(cat)
field() { printf '%s' "$input" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);const v=process.argv[1]==="cmd"?j.tool_input.command:j.cwd;console.log(v||"")}catch(e){console.log("")}})' "$1"; }
cmd=$(field cmd)
workdir=$(field cwd)

case "$cmd" in
  *"project deploy start"*|*"force:source:deploy"*) ;;
  *) exit 0 ;;
esac

if printf '%s' "$cmd" | grep -Eq -- '(--source-dir|-d)[ =]+"?force-app(/main/default)?/?"?([[:space:]]|$)'; then
  echo "Zablokováno: deploy celého force-app přepíše ve sdíleném orgu cizí práci. Nasaď jen soubory karty: sf project deploy start --source-dir <soubor> … (CLAUDE.md, Práce v týmu)." >&2
  exit 2
fi
if printf '%s' "$cmd" | grep -Eq -- '--manifest|-x[ =]'; then
  echo "Zablokováno: deploy přes manifest nasazuje celý projekt. Nasaď jen soubory karty přes --source-dir." >&2
  exit 2
fi

cd "${workdir:-${CLAUDE_PROJECT_DIR:-$(dirname "$0")/..}}" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0
git fetch --quiet origin 2>/dev/null || exit 0
upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo origin/main)
behind=$(git rev-list --count "HEAD..$upstream" 2>/dev/null || echo 0)
if [ "$behind" -gt 0 ]; then
  echo "Zablokováno: větev je $behind commitů za $upstream – deploy by v orgu vrátil starší verzi cizích tříd. Nejdřív bash scripts/git-sync.sh (nebo git pull --rebase), pak deploy." >&2
  exit 2
fi
exit 0
