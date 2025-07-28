import { LightningElement, api } from 'lwc';

export default class BalanceOverview extends LightningElement {
    @api remainingBalances = [];
    @api consumedBalances = [];
}