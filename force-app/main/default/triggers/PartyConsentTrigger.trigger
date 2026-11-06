trigger PartyConsentTrigger on PartyConsent(after insert, after update) {
    KapkaActivityService.handleConsents(Trigger.new, Trigger.oldMap);
}
