// Demo kapky-na-dosah: spustí noční kontrolu kapek na dosah hned.
// sf apex run --file scripts/run-nudge.apex
Database.executeBatch(new KapkaNudgeBatch());
