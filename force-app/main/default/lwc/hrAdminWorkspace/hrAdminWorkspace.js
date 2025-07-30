import { LightningElement } from 'lwc';

export default class HrAdminWorkspace extends LightningElement {
    activetabContent = 'my';
    
    tabChangeHandler(event) {
        this.activetabContent = event.target.value;
    }
}