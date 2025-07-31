import { refreshApex } from '@salesforce/apex';
import deleteBalance from '@salesforce/apex/LeaveBalanceController.deleteBalance';
import getBalances from '@salesforce/apex/LeaveBalanceController.getBalances';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { LightningElement, track, wire } from 'lwc';

const COLUMNS = [
    { label: 'Employee Name', fieldName: 'employeeUrl', type: 'url', typeAttributes: { label: { fieldName: 'EmployeeName' }, target: '_self' } },
    { label: 'Leave Type', fieldName: 'Leave_Type__c', type: 'text' },
    { label: 'Allocated Days', fieldName: 'Allocated_Days__c', type: 'number', cellAttributes: { alignment: 'left' } },
    { label: 'Used Days', fieldName: 'Used_Days__c', type: 'number', cellAttributes: { alignment: 'left' } },
    { label: 'Remaining Days', fieldName: 'Remaining_Days__c', type: 'number', cellAttributes: { alignment: 'left' } },
    { label: 'Year', fieldName: 'Year__c', type: 'text' },
    { label: 'Last Modified', fieldName: 'LastModifiedDate', type: 'date-local' },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Edit', name: 'edit' },
                { label: 'Delete', name: 'delete' }
            ]
        }
    }
];

const DEFAULT_FILTERS = {
    employeeName: '',
    leaveType: ''
};

export default class HrBalances extends LightningElement {
    @track columns = COLUMNS;
    @track balances = [];
    @track filteredBalances = [];
    @track filterValues = { ...DEFAULT_FILTERS };
    @track showFilterPopover = false;
    @track showBalanceModal = false;
    @track modalTitle = 'New Balance';
    @track selectedBalanceId = null;
    isLoading = true;
    wiredBalancesResult;

    leaveTypeOptions = [
        { label: 'All Types', value: '' },
        { label: 'Paid Leave', value: 'Paid Leave' },
        { label: 'RTT', value: 'RTT' },
        { label: 'Sick Leave', value: 'Sick Leave' },
        { label: 'Training', value: 'Training' }
    ];

    @wire(getBalances)
    wiredBalances(result) {
        this.isLoading = true;
        this.wiredBalancesResult = result;
        if (result.data) {
            this.balances = result.data.map(balance => ({
                ...balance,
                EmployeeName: balance.Employee__r ? balance.Employee__r.Name : '',
                employeeUrl: `/lightning/r/User/${balance.Employee__c}/view`
            }));
            this.applyFilters();
        } else if (result.error) {
            console.error('Error loading HR balances:', result.error);
            this.balances = [];
            this.filteredBalances = [];
        }
        this.isLoading = false;
    }

    handleRefresh() {
        this.isLoading = true;
        return refreshApex(this.wiredBalancesResult).finally(() => {
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
        let data = [...this.balances];
        const { employeeName, leaveType, employeeId } = this.filterValues;

        if (employeeName) {
            const lowerCaseName = employeeName.toLowerCase();
            data = data.filter(balance => balance.EmployeeName && balance.EmployeeName.toLowerCase().includes(lowerCaseName));
        }
        if (leaveType) {
            data = data.filter(balance => balance.Leave_Type__c === leaveType);
        }
        if (employeeId) {
            data = data.filter(balance => balance.Employee__c === employeeId); // Filter by Employee__c
        }
        this.filteredBalances = data;
    }

    get filterButtonVariant() {
        return this.showFilterPopover ? 'brand' : 'neutral';
    }

    get hasBalances() {
        return this.filteredBalances && this.filteredBalances.length > 0;
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        switch (actionName) {
            case 'edit':
                this.modalTitle = 'Edit Balance';
                this.selectedBalanceId = row.Id;
                this.showBalanceModal = true;
                break;
            case 'delete':
                if (confirm(`Are you sure you want to delete the ${row.EmployeeName} ${row.Leave_Type__c} balance?`)) {
                    this.isLoading = true;
                    deleteBalance({ balanceId: row.Id })
                        .then(() => {
                            this.showToast('Success', 'Balance deleted successfully.', 'success');
                            return this.handleRefresh();
                        })
                        .catch(error => {
                            console.error('Error deleting balance:', error);
                            this.showToast('Error', error.body.message, 'error');
                        })
                        .finally(() => {
                            this.isLoading = false;
                        });
                }
                break;
            default:
                break;
        }
    }

    handleNewBalance() {
        this.modalTitle = 'New Balance';
        this.selectedBalanceId = null;
        this.showBalanceModal = true;
    }

    closeBalanceModal() {
        this.showBalanceModal = false;
        this.selectedBalanceId = null;
    }

    handleBalanceSuccess() {
        this.showBalanceModal = false;
        if (this.selectedBalanceId) {
            this.showToast('Success', 'The balance has been successfully updated.', 'success');
        } else {
            this.showToast('Success', 'The balance has been successfully created.', 'success');
        }
        this.handleRefresh();
    }

    handleBalanceError(event) {
        const error = event.detail;
        console.error('Error saving balance:', error);
    
        let errorMessage = 'An error occurred while saving the balance.';
        if (error && error.body && error.body.output && error.body.output.errors && error.body.output.errors.length > 0) {
            errorMessage = error.body.output.errors[0].message;
        } else if (error && error.body && error.body.message) {
            errorMessage = error.body.message;
        } else if (error && error.detail) {
            errorMessage = error.detail;
        }

        this.showToast('Error', errorMessage, 'error');
    }

    handleBalanceSubmit(event) {
        if (!this.selectedBalanceId) {
            event.preventDefault();
            const fields = event.detail.fields;
            fields.Used_Days__c = 0;
            event.target.submit(fields);
        } else {
            const fields = event.detail.fields;
            event.target.submit(fields);
        }
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}