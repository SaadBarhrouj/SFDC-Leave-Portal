import { refreshApex } from '@salesforce/apex';
import getBalanceHistoryForCurrentUser from '@salesforce/apex/LeaveBalanceController.getBalanceHistoryForCurrentUser';
import REFRESH_BALANCE_CHANNEL from '@salesforce/messageChannel/RefreshBalanceChannel__c';
import { MessageContext, publish } from 'lightning/messageService';
import { LightningElement, track, wire } from 'lwc';
import USER_ID from '@salesforce/user/Id';

const HISTORY_COLUMNS_DEFINITION = [
    { label: 'Movement Date', fieldName: 'Movement_Date__c', type: 'date-local' },
    {
        label: 'Movement Type',
        fieldName: 'Movement_Type__c',
        type: 'customBadge',
        typeAttributes: {
            value: { fieldName: 'Movement_Type__c' },
            class: { fieldName: 'movementTypeBadgeClass' }
        }
    },
    { label: 'Leave Type', fieldName: 'Leave_Type__c', type: 'text' },
    { label: 'Source', fieldName: 'Source_of_Movement__c', type: 'text', wrapText: true },
    { label: 'Justification', fieldName: 'Justification__c', type: 'text', wrapText: true },
    { label: 'Days', fieldName: 'Number_of_Days__c', type: 'text' },
    { label: 'New Balance', fieldName: 'New_Balance__c', type: 'number', cellAttributes: { alignment: 'left' } }
];

const DEFAULT_FILTERS = {
    movementType: '',
    leaveType: '',
    startDate: null,
    endDate: null
};

export default class BalanceHistory extends LightningElement {
    @track historyData = [];
    @track filteredData = [];
    @track filterValues = { ...DEFAULT_FILTERS };
    @track historyColumns = HISTORY_COLUMNS_DEFINITION;
    @track showFilterPopover = false;
    @track currentUserName = '';
    isLoading = true;
    wiredHistoryResult;

    leaveTypeOptions = [
        { label: 'All Types', value: '' },
        { label: 'Paid Leave', value: 'Paid Leave' },
        { label: 'RTT', value: 'RTT' }
    ];

    movementTypeOptions = [
        { label: 'All Types', value: '' },
        { label: 'Accrual', value: 'Accrual' },
        { label: 'Deduction', value: 'Deduction' },
        { label: 'Correction', value: 'Correction' },
    ];

    @wire(getBalanceHistoryForCurrentUser)
    wiredHistory(result) {
        this.isLoading = true;
        this.wiredHistoryResult = result;
        if (result.data) {
            this.historyData = result.data.map(row => {
                const newRow = { ...row };
                const days = newRow.Number_of_Days__c;

                if (days != null && !isNaN(days)) {
                    if (days > 0) {
                        newRow.Number_of_Days__c = `+${days}`;
                    } else {
                        newRow.Number_of_Days__c = String(days);
                    }
                }

                newRow.movementTypeBadgeClass = this.getMovementTypeClass(newRow.Movement_Type__c);

                return newRow;
            });
            this.applyFilters();
        } else if (result.error) {
            console.error('Error loading balance history:', result.error);
            this.historyData = [];
            this.filteredData = [];
        }
        this.isLoading = false;
    }

    
    @wire(MessageContext)
    messageContext;

    handleRefresh() {
        this.isLoading = true;
        publish(this.messageContext, REFRESH_BALANCE_CHANNEL, {});
        return refreshApex(this.wiredHistoryResult).finally(() => {
            this.isLoading = false;
        });
    }

    toggleFilterPopover() {
        this.showFilterPopover = !this.showFilterPopover;
    }

    handleFilterChange(event) {
        const { name, value } = event.target;
        this.filterValues = { ...this.filterValues, [name]: value };
    }

    clearFilters() {
        this.filterValues = { ...DEFAULT_FILTERS };
        this.applyFilters();
    }

    applyFilters() {
        let data = [...this.historyData];
        const { movementType, leaveType, startDate, endDate } = this.filterValues;

        if (movementType) {
            data = data.filter(row => row.Movement_Type__c === movementType);
        }
        if (leaveType) {
            data = data.filter(row => row.Leave_Type__c === leaveType);
        }
        if (startDate) {
            data = data.filter(row => row.Movement_Date__c >= startDate);
        }
        if (endDate) {
            data = data.filter(row => row.Movement_Date__c <= endDate);
        }
        this.filteredData = data;
    }

    get filterButtonVariant() {
        return this.showFilterPopover ? 'brand' : 'neutral';
    }

    getMovementTypeClass(movementType) {
        switch (movementType) {
            default:
                return 'slds-badge';
        }
    }

    get hasData() {
        return this.filteredData && this.filteredData.length > 0;
    }

    handleExportPDF() {
    const params = [];
    if (this.filterValues.leaveType) params.push('type=' + encodeURIComponent(this.filterValues.leaveType));
    if (this.filterValues.startDate) params.push('start=' + this.filterValues.startDate);
    if (this.filterValues.endDate) params.push('end=' + this.filterValues.endDate);
    if (this.filterValues.movementType) params.push('movementType=' + encodeURIComponent(this.filterValues.movementType));
    const url = '/apex/MyBalanceHistoryExport' + (params.length ? '?' + params.join('&') : '');
    window.open(url, '_blank');
}
}
