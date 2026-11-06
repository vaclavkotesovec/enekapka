import { LightningElement } from 'lwc';
import getProfile from '@salesforce/apex/KapkaPortalCampaignController.getProfile';
import saveProfile from '@salesforce/apex/KapkaPortalCampaignController.saveProfile';
import setConsent from '@salesforce/apex/KapkaPortalCampaignController.setConsent';

export default class KapkaProfile extends LightningElement {
    profile;
    message;
    messageClass = 'ok';
    saving = false;

    connectedCallback() {
        this.load();
    }

    async load() {
        try {
            this.profile = { ...(await getProfile()) };
        } catch (e) {
            this.showError(e);
        }
    }

    get isPerson() {
        return this.profile && this.profile.isPerson;
    }

    handleChange(event) {
        this.profile = { ...this.profile, [event.target.name]: event.target.value };
    }

    async handleSave() {
        this.saving = true;
        try {
            await saveProfile({ profile: this.profile });
            this.show('Profil je uložený.');
        } catch (e) {
            this.showError(e);
        } finally {
            this.saving = false;
        }
    }

    async handleConsent(event) {
        const purpose = event.target.dataset.purpose;
        const optIn = event.target.checked;
        try {
            await setConsent({ purposeName: purpose, optIn });
            this.show(optIn ? 'Souhlas je udělený.' : 'Souhlas je odvolaný.');
            await this.load();
        } catch (e) {
            this.showError(e);
        }
    }

    show(text) {
        this.message = text;
        this.messageClass = 'ok';
    }

    showError(e) {
        this.message = (e && e.body && e.body.message) || 'Něco se nepovedlo, zkus to prosím znovu.';
        this.messageClass = 'error';
    }
}
