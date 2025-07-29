import getLeaveBalanceOverviews from '@salesforce/apex/LeaveBalanceController.getLeaveBalanceOverviews';
import { LightningElement, wire } from 'lwc';

const LEAVE_TYPE_CONFIG = {
    'RTT':        { unit: 'Days Available',  sourceField: 'remaining' },
    'Paid Leave':   { unit: 'Days Available',  sourceField: 'remaining' },
    'Unpaid Leave': { unit: 'Days Consumed',   sourceField: 'consumed' },
    'Sick Leave': { unit: 'Days Consumed',   sourceField: 'consumed' },
    'Training':   { unit: 'Days Consumed',   sourceField: 'consumed' },
};

const DISPLAYED_TYPES = ['RTT', 'Paid Leave', 'Unpaid Leave', 'Sick Leave', 'Training'];

export default class LeaveBalanceDashboard extends LightningElement {
    balances = [];
    error;

    @wire(getLeaveBalanceOverviews)
    wiredOverviews({ error, data }) {
        if (data) {
            this.balances = DISPLAYED_TYPES.map(leaveType => {
                const apexData = data.find(d => d.type === leaveType);
                const config = LEAVE_TYPE_CONFIG[leaveType];
                let value = '-';

                if (apexData) {
                    const rawValue = apexData[config.sourceField];
                    value = (rawValue !== null && rawValue !== undefined) ? rawValue : 0;
                }

                return {
                    id: leaveType,
                    label: leaveType,
                    value: value,
                    unit: config.unit
                };
            });
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.balances = [];
            console.error('Error loading balance overviews:', error);
        }
    }
}