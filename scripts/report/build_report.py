"""Manažerský report Kapka Klubu (karta report): načte data z orgu přes `sf` a vloží je do HTML.

Použití (z kořene repa, org = výchozí nebo --org alias):
    python scripts/report/build_report.py --out .work/report/kapka-report.html [--org kapka]

Rozhodnutí R1: hackathonový org není dostupný přes Salesforce konektor, report je snapshot
s časem načtení. Po nových datech v orgu stačí skript spustit znovu a artifact publikovat.
"""
import argparse
import json
import os
import shutil
import subprocess
from datetime import datetime, timezone

HERE = os.path.dirname(os.path.abspath(__file__))

QUERIES = {
    "members_by_status": "SELECT toLabel(Status__c) status, COUNT(Id) total FROM Loyalty_Member__c GROUP BY Status__c",
    "registrations_by_week": (
        "SELECT CALENDAR_YEAR(Enrollment_Date__c) y, WEEK_IN_YEAR(Enrollment_Date__c) w, COUNT(Id) total "
        "FROM Loyalty_Member__c WHERE Enrollment_Date__c != NULL "
        "GROUP BY CALENDAR_YEAR(Enrollment_Date__c), WEEK_IN_YEAR(Enrollment_Date__c)"
    ),
    "kapky_by_month": (
        "SELECT Type__c type, CALENDAR_YEAR(Transaction_Date__c) y, CALENDAR_MONTH(Transaction_Date__c) m, "
        "SUM(Points__c) kapky FROM Points_Transaction__c WHERE Status__c = 'Posted' "
        "GROUP BY Type__c, CALENDAR_YEAR(Transaction_Date__c), CALENDAR_MONTH(Transaction_Date__c)"
    ),
    "vouchers_by_reward": "SELECT Reward__c reward, COUNT(Id) total FROM Voucher__c GROUP BY Reward__c",
    "rewards": "SELECT Id, Name, Partner__r.Name, Points_Cost__c, Value_CZK__c, Is_Active__c FROM Reward__c",
    "campaigns": (
        "SELECT Loyalty_Campaign__r.Name name, COUNT(Id) purchases, "
        "COUNT_DISTINCT(Points_Transaction__r.Loyalty_Member__c) members, SUM(Points__c) kapky "
        "FROM Applied_Campaign__c GROUP BY Loyalty_Campaign__r.Name"
    ),
    "budget": "SELECT Voucher_Budget_CZK__c FROM Kapka_Program_Setting__mdt WHERE DeveloperName = 'Default'",
}


def sf_query(soql, org):
    sf = shutil.which("sf") or shutil.which("sf.cmd")
    cmd = [sf, "data", "query", "--query", soql, "--json"] + (["--target-org", org] if org else [])
    out = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8")
    data = json.loads(out.stdout)
    if data.get("status") != 0:
        raise SystemExit(f"Dotaz selhal: {soql}\n{data.get('message')}")
    rows = data["result"]["records"]
    for row in rows:
        row.pop("attributes", None)
    return rows


def build(org):
    raw = {key: sf_query(soql, org) for key, soql in QUERIES.items()}
    rewards = {r["Id"]: r for r in raw["rewards"]}
    vouchers = []
    for row in raw["vouchers_by_reward"]:
        reward = rewards.get(row["reward"], {})
        value = (reward.get("Value_CZK__c") or 0) * row["total"]
        vouchers.append({
            "name": reward.get("Name", "Neznámá odměna"),
            "partner": (reward.get("Partner__r") or {}).get("Name", ""),
            "count": row["total"],
            "valueCzk": value,
        })
    vouchers.sort(key=lambda v: (-v["count"], v["name"]))
    months = {}
    for row in raw["kapky_by_month"]:
        key = f'{row["y"]}-{row["m"]:02d}'
        months.setdefault(key, {"month": key, "earned": 0, "redeemed": 0, "expired": 0})
        kapky = row["kapky"] or 0
        if row["type"] == "Earn":
            months[key]["earned"] += kapky
        elif row["type"] == "Redeem":
            months[key]["redeemed"] += -kapky
        elif row["type"] == "Expire":
            months[key]["expired"] += -kapky
    budget = raw["budget"][0]["Voucher_Budget_CZK__c"] if raw["budget"] else None
    return {
        "fetchedAt": datetime.now(timezone.utc).isoformat(),
        "members": [{"status": r["status"], "count": r["total"]} for r in raw["members_by_status"]],
        "registrations": sorted(
            ({"week": f'{r["y"]}-T{r["w"]:02d}', "count": r["total"]} for r in raw["registrations_by_week"]),
            key=lambda r: r["week"],
        ),
        "kapky": sorted(months.values(), key=lambda m: m["month"]),
        "vouchers": vouchers,
        "campaigns": sorted(
            ({"name": r["name"], "purchases": r["purchases"], "members": r["members"], "kapky": r["kapky"] or 0}
             for r in raw["campaigns"]),
            key=lambda c: -c["kapky"],
        ),
        "budgetCzk": budget,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True)
    parser.add_argument("--org")
    args = parser.parse_args()
    data = build(args.org)
    template = open(os.path.join(HERE, "template.html"), encoding="utf-8").read()
    html = template.replace("/*__KAPKA_DATA__*/null", json.dumps(data, ensure_ascii=False))
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"Report: {args.out} (členů {sum(m['count'] for m in data['members'])}, voucherů {sum(v['count'] for v in data['vouchers'])})")


if __name__ == "__main__":
    main()
