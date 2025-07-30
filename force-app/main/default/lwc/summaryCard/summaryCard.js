import { LightningElement, api } from 'lwc';

export default class SummaryCard extends LightningElement {
    @api label;
    @api value;
    @api unit;
    @api iconName;
}