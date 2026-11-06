// Naplánuje kontrolu kapek na dosah na každou noc ve 3:00 (N4, po expiraci ve 2:00).
// sf apex run --file scripts/schedule-nudge.apex
System.debug(KapkaNudgeBatch.scheduleNightly());
