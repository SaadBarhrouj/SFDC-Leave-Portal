import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getBalances from '@salesforce/apex/LeaveBalanceController.getBalances';
import deleteBalanceWithJustification from '@salesforce/apex/LeaveBalanceController.deleteBalanceWithJustification';
import updateBalanceWithJustification from '@salesforce/apex/LeaveBalanceController.updateBalanceWithJustification';
import getLeavePolicySettings from '@salesforce/apex/LeaveBalanceController.getLeavePolicySettings';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import LEAVE_BALANCE_OBJECT from '@salesforce/schema/Leave_Balance__c';
import LEAVE_TYPE_FIELD from '@salesforce/schema/Leave_Balance__c.Leave_Type__c';

const COLUMNS = [
    {
        label: 'Employee Name', fieldName: 'employeeUrl', type: 'avatarType',
        typeAttributes: {
            avatarUrl: { fieldName: 'EmployeeFullPhotoUrl' },
            name: { fieldName: 'EmployeeName' },
            url: { fieldName: 'employeeUrl' },
            initials: { fieldName: 'EmployeeInitials' }
        }
    },
    { label: 'Leave Type', fieldName: 'Leave_Type__c', type: 'text' },
    { label: 'Allocated', fieldName: 'Allocated_Days__c', type: 'number', cellAttributes: { alignment: 'left' } },
    { label: 'Used', fieldName: 'Used_Days__c', type: 'number', cellAttributes: { alignment: 'left' } },
    { label: 'Remaining', fieldName: 'Remaining_Days__c', type: 'number', cellAttributes: { alignment: 'left' } },
    { label: 'Year', fieldName: 'Year__c', type: 'text' },
    { type: 'action', typeAttributes: { rowActions: [{ label: 'Edit', name: 'edit' }, { label: 'Delete', name: 'delete' }] } }
];

const DEFAULT_FILTERS = { employeeName: '', leaveType: '' };

export default class HrBalances extends LightningElement {
    @track columns = COLUMNS;
    @track balances = [];
    @track filteredBalances = [];
    @track filterValues = { ...DEFAULT_FILTERS };
    @track showFilterPopover = false;
    @track showBalanceModal = false;
    @track showCorrectionModal = false;
    @track showDeleteModal = false;
    @track modalTitle = 'New Balance';
    @track selectedBalanceId = null;
    @track correctionData = {};
    @track originalAllocatedDays;
    @track leaveTypeOptions = [];
    @track allocatedDaysValue;
    leaveTypeValue = '';
    currentYear = new Date().getFullYear();
    balanceToDelete = {};
    deleteJustification = '';
    isLoading = true;
    wiredBalancesResult;
    leavePolicySettings;

    leaveTypeBalanceOptions = [
        { label: 'All', value: '' },
        { label: 'RTT', value: 'RTT' },
        { label: 'Paid Leave', value: 'Paid Leave' }
    ];

    @wire(getObjectInfo, { objectApiName: LEAVE_BALANCE_OBJECT })
    objectInfo;

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: LEAVE_TYPE_FIELD })
    wiredPicklistValues({ error, data }) {
        if (data) {
            this.leaveTypeOptions = data.values.filter(option =>
                option.value === 'RTT' || option.value === 'Paid Leave'
            );
        } else if (error) {
            this.showToast('Error', 'Error loading leave types.', 'error');
        }
    }

    @wire(getLeavePolicySettings)
    wiredLeavePolicySettings({ error, data }) {
        if (data) {
            this.leavePolicySettings = data;
        } else if (error) {
            this.showToast('Error', 'Could not load leave policy settings.', 'error');
        }
    }

    @wire(getBalances)
    wiredBalances(result) {
        this.isLoading = true;
        this.wiredBalancesResult = result;
        if (result.data) {
            this.balances = result.data.map(balance => {
                const empName = (balance.Employee__r && balance.Employee__r.Name)
                    ? balance.Employee__r.Name
                    : 'Unknown User';

                let initials = 'UU';
                if (empName && empName !== 'Unknown User') {
                    const nameParts = empName.trim().split(' ').filter(part => part);
                    if (nameParts.length > 1) {
                        initials = (nameParts[0].charAt(0) + nameParts[nameParts.length - 1].charAt(0)).toUpperCase();
                    } else if (nameParts.length === 1 && nameParts[0].length > 0) {
                        initials = nameParts[0].substring(0, 2).toUpperCase();
                    }
                }

                return {
                    ...balance,
                    EmployeeName: empName,
                    employeeUrl: `/lightning/r/User/${balance.Employee__c}/view`,
                    EmployeeFullPhotoUrl: balance.Employee__r ? balance.Employee__r.FullPhotoUrl : '',
                    EmployeeInitials: initials
                };
            });

            this.applyFilters();

        } else if (result.error) {
            this.showToast('Error', 'Error loading balances.', 'error');
        }
        this.isLoading = false;
    }

    applyFilters() {
        const { employeeName, leaveType } = this.filterValues;
        let data = [...this.balances];
        if (employeeName) {
            data = data.filter(b => b.EmployeeName && b.EmployeeName.toLowerCase().includes(employeeName.toLowerCase()));
        }
        if (leaveType) {
            data = data.filter(b => b.Leave_Type__c === leaveType);
        }
        this.filteredBalances = data;
    }

    handleFilterChange(event) {
        const { name, value } = event.target;
        this.filterValues = { ...this.filterValues, [name]: value };
    }

    clearFilters() {
        this.filterValues = { ...DEFAULT_FILTERS };
        this.applyFilters();
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'edit') {
            this.originalAllocatedDays = row.Allocated_Days__c;
            this.correctionData = {
                Id: row.Id,
                EmployeeName: row.EmployeeName,
                Leave_Type__c: row.Leave_Type__c,
                Allocated_Days__c: row.Allocated_Days__c,
                justification: ''
            };
            this.showCorrectionModal = true;
        } else if (actionName === 'delete') {
            this.balanceToDelete = { Id: row.Id, EmployeeName: row.EmployeeName, Leave_Type__c: row.Leave_Type__c };
            this.deleteJustification = '';
            this.showDeleteModal = true;
        }
    }

    closeCorrectionModal() {
        this.showCorrectionModal = false;
        this.correctionData = {};
        this.originalAllocatedDays = undefined;
    }

    closeDeleteModal() {
        this.showDeleteModal = false;
        this.balanceToDelete = {};
        this.deleteJustification = '';
    }

    handleDeleteJustificationChange(event) {
        this.deleteJustification = event.target.value;
    }

    get isDeleteDisabled() {
        return !this.deleteJustification || this.deleteJustification.trim() === '';
    }

    handleDeleteWithJustification() {
        this.isLoading = true;
        deleteBalanceWithJustification({
            balanceId: this.balanceToDelete.Id,
            justification: this.deleteJustification
        })
            .then(() => {
                this.showToast('Success', 'Balance deleted successfully.', 'success');
                this.closeDeleteModal();
                return this.handleRefresh();
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleCorrectionChange(event) {
        const { name, value } = event.target;
        if (name === 'Allocated_Days__c') {
            this.correctionData = { ...this.correctionData, [name]: parseFloat(value) };
        } else {
            this.correctionData = { ...this.correctionData, [name]: value };
        }
    }

    get isSaveCorrectionDisabled() {
        return !this.correctionData.justification || this.correctionData.justification.trim() === '' || this.correctionData.Allocated_Days__c === this.originalAllocatedDays;
    }

    saveCorrection() {
        this.isLoading = true;
        updateBalanceWithJustification({
            balanceId: this.correctionData.Id,
            newAllocatedDays: this.correctionData.Allocated_Days__c,
            justification: this.correctionData.justification
        })
            .then(() => {
                this.showToast('Success', 'Balance modified successfully.', 'success');
                this.closeCorrectionModal();
                return this.handleRefresh();
            })
            .catch(error => this.showToast('Error', error.body.message, 'error'))
            .finally(() => { this.isLoading = false; });
    }

    handleNewBalance() {
        this.modalTitle = 'New Balance';
        this.selectedBalanceId = null;
        this.leaveTypeValue = '';
        this.allocatedDaysValue = null;
        this.showBalanceModal = true;
    }

    closeBalanceModal() {
        this.showBalanceModal = false;
    }

    handleBalanceSuccess() {
        this.showBalanceModal = false;
        const message = this.selectedBalanceId ? 'Balance updated successfully.' : 'Balance created successfully.';
        this.showToast('Success', message, 'success');
        this.handleRefresh();
    }

    handleRefresh() {
        this.isLoading = true;
        return refreshApex(this.wiredBalancesResult).finally(() => { this.isLoading = false; });
    }

    toggleFilterPopover() { this.showFilterPopover = !this.showFilterPopover; }
    get filterButtonVariant() { return this.showFilterPopover ? 'brand' : 'neutral'; }
    get hasBalances() { return this.filteredBalances && this.filteredBalances.length > 0; }
    showToast(title, message, variant) { this.dispatchEvent(new ShowToastEvent({ title, message, variant })); }

    handleBalanceError(event) {
        let errorMessage = 'An error occurred while saving the balance.';
        if (event.detail.output && event.detail.output.errors && event.detail.output.errors.length > 0) {
            errorMessage = event.detail.output.errors.map(error => error.message).join(', ');
        }
        else if (event.detail && event.detail.message) {
            errorMessage = event.detail.message;
        }
        this.showToast('Error', errorMessage, 'error');
    }

    handleLeaveTypeChange(event) {
        this.leaveTypeValue = event.detail.value;
        if (this.leavePolicySettings) {
            if (this.leaveTypeValue === 'RTT') {
                this.allocatedDaysValue = this.leavePolicySettings.Annual_RTT_Days__c;
            } else if (this.leaveTypeValue === 'Paid Leave') {
                this.allocatedDaysValue = this.leavePolicySettings.Annual_Paid_Leave_Days__c;
            } else {
                this.allocatedDaysValue = null;
            }
        }
    }

    handleAllocatedDaysChange(event) {
        this.allocatedDaysValue = event.target.value;
    }

    handleBalanceSubmit(event) {
        event.preventDefault();
        const fields = event.detail.fields;
        if (!this.selectedBalanceId) {
            fields.Used_Days__c = 0;
        }
        fields.Leave_Type__c = this.leaveTypeValue;
        fields.Allocated_Days__c = this.allocatedDaysValue;
        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }
}