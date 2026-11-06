import { LightningElement, wire } from 'lwc';
import basePath from '@salesforce/community/basePath';
import getActivities from '@salesforce/apex/KapkaPortalCampaignController.getActivities';

const NAMES = { Profile: 'Dokončení profilu', Consent: 'Souhlas s marketingem' };

export default class KapkaActivities extends LightningElement {
    activities = [];
    error;
    profileUrl = `${basePath}/profil`;

    @wire(getActivities)
    wired({ data, error }) {
        if (data) {
            this.activities = data.map((a) => ({
                ...a,
                name: NAMES[a.source] || a.source,
                pointsLabel: a.points ? `+${a.points} kapek` : '',
                statusLabel: a.done ? 'Splněno' : 'Nesplněno',
                statusClass: a.done ? 'done' : 'todo'
            }));
            this.error = undefined;
        } else if (error) {
            this.error = 'Aktivity se teď nepodařilo načíst.';
        }
    }
}
