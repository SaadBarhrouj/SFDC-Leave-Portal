import { LightningElement } from 'lwc';

export default class HrAdminWorkspace extends LightningElement {
    activetabContent = 'balances';
    
    tabChangeHandler(event) {
        this.activetabContent = event.target.value;
    }
}