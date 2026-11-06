import { LightningElement, wire } from 'lwc';
import getCurrentMember from '@salesforce/apex/KapkaPortalController.getCurrentMember';

const THOUSANDS = new Intl.NumberFormat('cs-CZ', { maximumFractionDigits: 0 });

/** Úvod portálu: jméno a stav člena, zůstatek kapek jantarem na ploše hlubina. */
export default class KapkaMemberHeader extends LightningElement {
    member;
    errorMessage;

    @wire(getCurrentMember)
    wiredMember({ data, error }) {
        this.member = data;
        this.errorMessage = error ? error.body?.message : undefined;
    }

    get balanceText() {
        return THOUSANDS.format(this.member?.balance ?? 0);
    }
}
