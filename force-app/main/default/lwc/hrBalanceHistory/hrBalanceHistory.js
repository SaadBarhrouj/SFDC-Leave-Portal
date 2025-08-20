import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getAllBalanceHistory from '@salesforce/apex/LeaveBalanceController.getAllBalanceHistory';

const COLUMNS = [
    {
        label: 'Employee Name',
        fieldName: 'employeeUrl',
        type: 'avatarType',
        typeAttributes: {
            avatarUrl: { fieldName: 'EmployeeFullPhotoUrl' },
            name: { fieldName: 'EmployeeName' },
            url: { fieldName: 'employeeUrl' },
            initials: { fieldName: 'EmployeeInitials' }
        }
    },
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
    employeeName: '',
    movementType: '',
    leaveType: '',
    startDate: null,
    endDate: null
};

export default class HrBalanceHistory extends LightningElement {
    @track columns = COLUMNS;
    @track originalHistory = [];
    @track filteredHistory = [];
    @track filterValues = { ...DEFAULT_FILTERS };
    @track showFilterPopover = false;
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

    @wire(getAllBalanceHistory)
    wiredHistory(result) {
        this.isLoading = true;
        this.wiredHistoryResult = result;
        if (result.data) {
            this.originalHistory = result.data.map(item => {
                const employeeName = item.Employee__r ? item.Employee__r.Name : 'Unknown User';
                let employeeInitials = 'UU';
                if (employeeName && employeeName !== 'Unknown User') {
                    const nameParts = employeeName.trim().split(' ').filter(part => part);
                    if (nameParts.length > 1) {
                        employeeInitials = (nameParts[0].charAt(0) + nameParts[nameParts.length - 1].charAt(0)).toUpperCase();
                    } else if (nameParts.length === 1 && nameParts[0].length > 0) {
                        employeeInitials = employeeName.substring(0, 2).toUpperCase();
                    }
                }

                const days = item.Number_of_Days__c;
                let formattedDays = String(days);
                if (days != null && !isNaN(days) && days > 0) {
                    formattedDays = `+${days}`;
                }

                return {
                    ...item,
                    EmployeeName: employeeName,
                    employeeUrl: item.Employee__r ? `/lightning/r/User/${item.Employee__c}/view` : '',
                    EmployeeFullPhotoUrl: item.Employee__r ? item.Employee__r.FullPhotoUrl : '',
                    EmployeeInitials: employeeInitials,
                    movementTypeBadgeClass: this.getMovementTypeClass(item.Movement_Type__c),
                    Number_of_Days__c: formattedDays
                };
            });
            this.applyFilters();
        } else if (result.error) {
            console.error('Error fetching all balance history:', result.error);
            this.originalHistory = [];
            this.filteredHistory = [];
        }
        this.isLoading = false;
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
        let data = [...this.originalHistory];
        const { employeeName, movementType, leaveType, startDate, endDate } = this.filterValues;

        if (employeeName) {
            const lowerCaseName = employeeName.toLowerCase();
            data = data.filter(item => item.EmployeeName && item.EmployeeName.toLowerCase().includes(lowerCaseName));
        }
        if (movementType) {
            data = data.filter(item => item.Movement_Type__c === movementType);
        }
        if (leaveType) {
            data = data.filter(item => item.Leave_Type__c === leaveType);
        }
        if (startDate) {
            data = data.filter(item => item.Movement_Date__c >= startDate);
        }
        if (endDate) {
            data = data.filter(item => item.Movement_Date__c <= endDate);
        }

        this.filteredHistory = data;
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredHistoryResult).finally(() => {
            this.isLoading = false;
        });
    }

  handleExportHRReports() {
    const params = [];
    if (this.filterValues.employeeName) params.push('employee=' + encodeURIComponent(this.filterValues.employeeName));
    if (this.filterValues.leaveType) params.push('type=' + encodeURIComponent(this.filterValues.leaveType));
    if (this.filterValues.startDate) params.push('start=' + this.filterValues.startDate);
    if (this.filterValues.endDate) params.push('end=' + this.filterValues.endDate);
    if (this.filterValues.movementType) params.push('movementType=' + encodeURIComponent(this.filterValues.movementType));

    const url = '/apex/HRAllBalancesHistoryExport' + (params.length ? '?' + params.join('&') : '');
    window.open(url, '_blank');
}

    getMovementTypeClass(movementType) {
        switch (movementType) {
            default: return 'slds-badge';
        }
    }

    get filterButtonVariant() {
        return this.showFilterPopover ? 'brand' : 'neutral';
    }

    get hasHistory() {
        return this.filteredHistory && this.filteredHistory.length > 0;
    }
}