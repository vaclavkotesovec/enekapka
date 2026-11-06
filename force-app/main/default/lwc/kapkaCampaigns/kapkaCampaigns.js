import { LightningElement, wire } from 'lwc';
import getActiveCampaigns from '@salesforce/apex/KapkaPortalCampaignController.getActiveCampaigns';

const DATE = new Intl.DateTimeFormat('cs-CZ');

export default class KapkaCampaigns extends LightningElement {
    campaigns = [];
    error;

    @wire(getActiveCampaigns)
    wired({ data, error }) {
        if (data) {
            this.campaigns = data.map((c) => ({
                ...c,
                validity: c.validTo ? `Platí do ${DATE.format(new Date(c.validTo))}` : 'Platí bez omezení'
            }));
            this.error = undefined;
        } else if (error) {
            this.error = 'Kampaně se teď nepodařilo načíst.';
        }
    }

    get hasCampaigns() {
        return this.campaigns.length > 0;
    }
}
