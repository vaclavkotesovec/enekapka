import { LightningElement, wire } from 'lwc';
import getRewards from '@salesforce/apex/KapkaPortalRewardController.getRewards';
import getMyVouchers from '@salesforce/apex/KapkaPortalRewardController.getMyVouchers';

const DATE = new Intl.DateTimeFormat('cs-CZ');
const NUM = new Intl.NumberFormat('cs-CZ');

export default class KapkaRewardCatalog extends LightningElement {
    rewards = [];
    vouchers = [];
    error;

    @wire(getRewards)
    wiredRewards({ data, error }) {
        if (data) {
            this.rewards = data.map((r) => ({
                ...r,
                costLabel: `${NUM.format(r.pointsCost)} kapek`,
                missingLabel: r.missingKapky > 0 ? `chybí ${NUM.format(r.missingKapky)} kapek` : '',
                cannotRedeem: r.missingKapky > 0
            }));
        } else if (error) {
            this.error = 'Katalog odměn se teď nepodařilo načíst.';
        }
    }

    @wire(getMyVouchers)
    wiredVouchers({ data, error }) {
        if (data) {
            this.vouchers = data.map((v) => ({
                ...v,
                issued: v.issuedDate ? DATE.format(new Date(v.issuedDate)) : ''
            }));
        } else if (error) {
            this.error = 'Vouchery se teď nepodařilo načíst.';
        }
    }

    get hasVouchers() {
        return this.vouchers.length > 0;
    }
}
