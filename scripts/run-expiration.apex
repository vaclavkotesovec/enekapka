// Demo: spustí expiraci kapek hned, bez čekání na noční běh ve 2:00 (X1).
// sf apex run --file scripts/run-expiration.apex --target-org kapka
Database.executeBatch(new KapkaExpirationBatch(), 200);
