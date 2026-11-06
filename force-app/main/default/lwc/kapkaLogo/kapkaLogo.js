import { LightningElement } from 'lwc';
import basePath from '@salesforce/community/basePath';
import KAPKA_MARK from '@salesforce/resourceUrl/kapkaMark';

/** Logotyp Kapka do hlavičky portálu: značka + slovo „kapka“ (Kapka Brand Kit, Logo). */
export default class KapkaLogo extends LightningElement {
    markUrl = KAPKA_MARK;
    homeUrl = basePath || '/';
}
