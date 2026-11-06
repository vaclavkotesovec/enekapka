import { LightningElement, wire } from 'lwc';
import getHistory from '@salesforce/apex/KapkaPortalController.getHistory';
import TITLE from '@salesforce/label/c.Kapka_Portal_HistoryTitle';
import EMPTY_HISTORY from '@salesforce/label/c.Kapka_Portal_EmptyHistory';

const DATE_FORMAT = new Intl.DateTimeFormat('cs-CZ', { day: 'numeric', month: 'numeric', year: 'numeric' });

/** Posledních 50 pohybů kapek s datem, typem, důvodem a kapkami (portal-zustatek AC-3). */
export default class KapkaHistory extends LightningElement {
    rows = [];
    loaded = false;
    error;
    labels = { title: TITLE, empty: EMPTY_HISTORY };

    @wire(getHistory)
    wiredHistory({ data, error }) {
        if (data) {
            this.rows = data.map((row) => ({
                ...row,
                dateText: row.transactionDate ? DATE_FORMAT.format(new Date(row.transactionDate)) : '',
                pointsText: (row.points > 0 ? '+' : '') + Number(row.points).toLocaleString('cs-CZ'),
                pointsClass: row.points < 0 ? 'points kapka-minus' : 'points kapka-plus'
            }));
            this.loaded = true;
        }
        this.error = error ? (error.body && error.body.message) || String(error) : undefined;
    }

    get isEmpty() {
        return this.loaded && this.rows.length === 0;
    }
}
