import { LightningElement, wire } from 'lwc';
import getCurrentMember from '@salesforce/apex/KapkaPortalController.getCurrentMember';
import EXPIRING from '@salesforce/label/c.Kapka_Portal_Expiring';
import EMPTY_HISTORY from '@salesforce/label/c.Kapka_Portal_EmptyHistory';
import BALANCE from '@salesforce/label/c.Kapka_Portal_Balance';

/** Zůstatek kapek přihlášeného člena a upozornění na kapky, které do 30 dnů vyprší (portal-zustatek AC-1, AC-2). */
export default class KapkaBalance extends LightningElement {
    member;
    error;
    labels = { balance: BALANCE, emptyHistory: EMPTY_HISTORY };

    @wire(getCurrentMember)
    wiredMember({ data, error }) {
        this.member = data;
        this.error = error ? (error.body && error.body.message) || String(error) : undefined;
    }

    get balance() {
        return this.member ? Number(this.member.balance || 0).toLocaleString('cs-CZ') : '';
    }

    get hasExpiring() {
        return Boolean(this.member && this.member.expiringSoon > 0);
    }

    get expiringText() {
        return EXPIRING.replace('{0}', Number(this.member.expiringSoon).toLocaleString('cs-CZ'));
    }

    get isNewMember() {
        return Boolean(this.member && !this.member.balance);
    }
}
