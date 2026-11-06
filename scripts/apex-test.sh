#!/usr/bin/env bash
# Spustí Apex testovací třídy ve sdíleném orgu po jedné a při zahlcené frontě
# (ALREADY_IN_PROCESS, UNKNOWN_EXCEPTION) to sám zkouší znovu.
#   bash scripts/apex-test.sh KapkaEarnServiceTest KapkaCampaignEvaluatorTest [--coverage]
# Vypíše výsledek každého testu, který neprošel, a souhrn; exit 1, když něco selhalo.
coverage=""
classes=()
for arg in "$@"; do
  if [ "$arg" = "--coverage" ]; then coverage="--code-coverage"; else classes+=("$arg"); fi
done
[ ${#classes[@]} -eq 0 ] && { echo "Použití: bash scripts/apex-test.sh <TřídaTest> [...] [--coverage]"; exit 2; }

failed=0
for cls in "${classes[@]}"; do
  for attempt in $(seq 1 30); do
    out=$(sf apex run test --class-names "$cls" --result-format human --wait 30 $coverage 2>&1)
    if printf '%s' "$out" | grep -qE 'ALREADY_IN_PROCESS|UNKNOWN_EXCEPTION|Unable to (submit|complete)'; then
      sleep 20
      continue
    fi
    break
  done
  outcome=$(printf '%s\n' "$out" | grep -E '^Outcome' | awk '{print $2}')
  ran=$(printf '%s\n' "$out" | grep -E '^Tests Ran' | awk '{print $3}')
  echo "== $cls: ${outcome:-NEZNÁMÝ VÝSLEDEK} (${ran:-?} testů)"
  printf '%s\n' "$out" | grep -E ' (Fail|CompileFail) ' | cut -c1-240
  [ -n "$coverage" ] && printf '%s\n' "$out" | grep -E '^Kapka|^Order' | grep -E '%' | grep -v Test | cut -c1-120
  [ "$outcome" = "Passed" ] || failed=1
done
exit $failed
