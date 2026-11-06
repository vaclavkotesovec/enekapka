// Demo: spustí win-back kontrolu hned, bez čekání na noční běh ve 3:30 (W4).
// sf apex run --file scripts/run-winback.apex --target-org kapka
Database.executeBatch(new KapkaWinbackBatch(), 200);
