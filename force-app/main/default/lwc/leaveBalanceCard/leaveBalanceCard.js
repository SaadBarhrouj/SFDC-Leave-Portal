import { LightningElement, api } from 'lwc';

export default class LeaveBalanceCard extends LightningElement {
    @api label;
    @api value;
    @api unit;
    @api iconName;
}