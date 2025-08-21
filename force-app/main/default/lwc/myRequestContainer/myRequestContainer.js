import { refreshApex } from '@salesforce/apex';
import cancelLeaveRequest from '@salesforce/apex/LeaveRequestController.cancelLeaveRequest';
import getMyLeaves from '@salesforce/apex/LeaveRequestController.getMyLeaves';
import requestCancellation from '@salesforce/apex/LeaveRequestController.requestCancellation';
import withdrawCancellationRequest from '@salesforce/apex/LeaveRequestController.withdrawCancellationRequest';
import CLEAR_SELECTION_CHANNEL from '@salesforce/messageChannel/ClearSelectionChannel__c';
import LEAVE_DATA_FOR_CALENDAR_CHANNEL from '@salesforce/messageChannel/LeaveDataForCalendarChannel__c';
import LEAVE_REQUEST_MODIFIED_CHANNEL from '@salesforce/messageChannel/LeaveRequestModifiedChannel__c';
import LEAVE_REQUEST_SELECTED_CHANNEL from '@salesforce/messageChannel/LeaveRequestSelectedChannel__c';
import REFRESH_BALANCE_CHANNEL from '@salesforce/messageChannel/RefreshBalanceChannel__c';
import REFRESH_LEAVE_DATA_CHANNEL from '@salesforce/messageChannel/RefreshLeaveDataChannel__c';
import { MessageContext, publish, subscribe } from 'lightning/messageService';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { LightningElement, track, wire } from 'lwc';

const COLUMNS = [
    { label: 'Request Name', fieldName: 'Name', type: 'button', typeAttributes: { label: { fieldName: 'RequestNumber' }, name: 'show_details', variant: 'base' } },
    { label: 'Leave Type', fieldName: 'Leave_Type__c' },
    { label: 'Start Date', fieldName: 'Start_Date__c', type: 'date-local' },
    { label: 'End Date', fieldName: 'End_Date__c', type: 'date-local' },
    { label: 'Days Requested', fieldName: 'Number_of_Days_Requested__c', type: 'number', cellAttributes: { alignment: 'left' } },
    { label: 'Status', fieldName: 'Status__c', type: 'customBadge', typeAttributes: { value: { fieldName: 'Status__c' }, class: { fieldName: 'statusBadgeClass' } }, initialWidth: 220 },
    { label: 'Last Modified', fieldName: 'LastModifiedDate', type: 'date', typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' } },
    { type: 'action', typeAttributes: { rowActions: { fieldName: 'availableActions' } } }
];

const DEFAULT_FILTERS = {
    status: 'All',
    leaveType: '',
    startDate: null,
    endDate: null
};

export default class MyRequestContainer extends LightningElement {
    @track requests = [];
    @track isLoading = false;
    @track selectedStatus = 'All';
    @track showCreateModal = false;
    @track recordIdToEdit = null;
    @track filterValues = { ...DEFAULT_FILTERS };
    @track filteredRequestsData = [];
    showFilterPopover = false;

    columns = COLUMNS;
    wiredRequestsResult;
    subscriptionClearSelection;

    statusOptions = [
        { label: 'All Status', value: 'All' }, { label: 'Approved', value: 'Approved' }, { label: 'Submitted', value: 'Submitted' },
        { label: 'Pending Manager Approval', value: 'Pending Manager Approval' }, { label: 'Pending HR Approval', value: 'Pending HR Approval' },
        { label: 'Escalated to Senior Manager', value: 'Escalated to Senior Manager' }, { label: 'Rejected', value: 'Rejected' },
        { label: 'Cancelled', value: 'Cancelled' }, { label: 'Cancellation Requested', value: 'Cancellation Requested' }
    ];

    leaveTypeOptions = [
        { label: 'All Types', value: '' },
        { label: 'Paid Leave', value: 'Paid Leave' },
        { label: 'RTT', value: 'RTT' },
        { label: 'Sick Leave', value: 'Sick Leave' },
        { label: 'Training', value: 'Training' },
    ];

    @wire(MessageContext) messageContext;

    @wire(getMyLeaves)
    wiredRequests(result) {
        this.wiredRequestsResult = result;
        if (result.data) {
            this.requests = this.processRequestsForDisplay(result.data);
            this.applyFilters();
        } else if (result.error) {
            this.showError(result.error?.body?.message || 'Error loading requests.');
        }
    }

    connectedCallback() {
        this.subscribeToClearSelection();
    }

    get filteredRequests() {
        return this.filteredRequestsData.length || this.hasActiveFilters() ? this.filteredRequestsData : this.requests;
    }

    get filterButtonVariant() {
        return this.showFilterPopover ? 'brand' : 'neutral';
    }

    hasActiveFilters() {
        const { status, leaveType, startDate, endDate } = this.filterValues;
        return (
            (status && status !== 'All') ||
            leaveType ||
            startDate ||
            endDate
        );
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
        let data = [...this.requests];
        const { status, leaveType, startDate, endDate } = this.filterValues;

        if (status && status !== 'All') {
            data = data.filter(req => req.Status__c === status);
        }
        if (leaveType) {
            data = data.filter(req => req.Leave_Type__c === leaveType);
        }
        if (startDate) {
            data = data.filter(req => req.Start_Date__c >= startDate);
        }
        if (endDate) {
            data = data.filter(req => req.End_Date__c <= endDate);
        }
        this.filteredRequestsData = data;
    }
    
    handleNewRequest() {
        this.recordIdToEdit = null;
        this.showCreateModal = true;
    }

    handleRowAction(event) {
        const { action, row } = event.detail;
        switch (action.name) {
            case 'show_details': this.publishSelection(row.Id, true); break;
            case 'edit': this.editRequest(row); break;
            case 'cancel': this.cancelRequest(row); break;
            case 'request_cancellation': this.requestCancellation(row); break;
            case 'withdraw_cancellation': this.withdrawCancellation(row); break;
            default: break;
        }
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        if (selectedRows.length === 1) {
            this.publishSelection(selectedRows[0].Id, false);
        }
    }

    editRequest(row) {
        this.recordIdToEdit = row.Id;
        this.showCreateModal = true;
    }

    closeCreateModal() {
        this.showCreateModal = false;
        this.recordIdToEdit = null;
    }

    handleModalSuccess(event) {
        const { recordId } = event.detail || {};

        if (!this.showCreateModal || !recordId) {
            return;
        }

        const message = this.recordIdToEdit ? 'Leave request updated successfully!' : 'Leave request created successfully!';
        this.showSuccess(message);
        this.closeCreateModal();

        this.refreshRequests().then(() => {
            this.publishRefreshRequest(recordId);
            this.publishSelection(recordId, true);
        });
    }

    handleModalFileChange(event) {
        this.publishRefreshRequest(event.detail.recordId);
    }

    refreshRequests() {
        this.isLoading = true;
        publish(this.messageContext, LEAVE_REQUEST_MODIFIED_CHANNEL, {});
        publish(this.messageContext, REFRESH_BALANCE_CHANNEL, {});
        return refreshApex(this.wiredRequestsResult)
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleRefresh() {
        this.isLoading = true;
        const payload = {
            context: 'my'
        };
        publish(this.messageContext, LEAVE_DATA_FOR_CALENDAR_CHANNEL, payload);
        publish(this.messageContext, LEAVE_REQUEST_MODIFIED_CHANNEL, {});
        publish(this.messageContext, REFRESH_BALANCE_CHANNEL, {});
        return refreshApex(this.wiredRequestsResult)
            .finally(() => {
                this.isLoading = false;
            });
    }

    cancelRequest(row) {
        if (confirm(`Are you sure you want to cancel request ${row.RequestNumber}?`)) {
            this.isLoading = true;
            cancelLeaveRequest({ requestId: row.Id })
                .then(result => {
                    this.showSuccess(result);
                    this.refreshRequests();
                })
                .catch(error => {
                    console.error('Error in cancelRequest:', error);
                    this.showError(error.body.message);
                })
                .finally(() => this.isLoading = false);
        }
    }

    requestCancellation(row) {
        if (confirm(`Are you sure you want to request cancellation for ${row.RequestNumber}?`)) {
            this.isLoading = true;
            requestCancellation({ leaveRequestId: row.Id })
                .then(() => {
                    this.showSuccess('Cancellation request submitted.');
                    this.refreshRequests();
                })
                .catch(error => {
                    console.error('Error in requestCancellation:', error);
                    this.showError(error.body.message);
                })
                .finally(() => this.isLoading = false);
        }
    }

    withdrawCancellation(row) {
        if (confirm(`Are you sure you want to withdraw the cancellation request for ${row.RequestNumber}?`)) {
            this.isLoading = true;
            withdrawCancellationRequest({ leaveRequestId: row.Id })
                .then(() => {
                    this.showSuccess('Cancellation request withdrawn.');
                    this.refreshRequests();
                })
                .catch(error => {
                    console.error('Error in withdrawCancellation:', error);
                    this.showError(error.body.message);
                })
                .finally(() => this.isLoading = false);
        }
    }

    subscribeToClearSelection() {
        if (this.subscriptionClearSelection) return;
        this.subscriptionClearSelection = subscribe(this.messageContext, CLEAR_SELECTION_CHANNEL, () => {
            this.refs.leaveRequestList?.clearSelection();
        });
    }

    publishSelection(recordId, selectRowInTable) {
        publish(this.messageContext, LEAVE_REQUEST_SELECTED_CHANNEL, { recordId, context: 'myRequest' });
        if (selectRowInTable) {
            this.refs.leaveRequestList?.setSelectedRows([recordId]);
        }
    }

    publishRefreshRequest(recordId) {
        publish(this.messageContext, REFRESH_LEAVE_DATA_CHANNEL, { recordId });
    }

    processRequestsForDisplay(rawData) {
        return rawData.map(request => {
            let availableActions = [];
            switch (request.Status__c) {
                case 'Approved':
                    availableActions.push({ label: 'Show details', name: 'show_details' });
                        if (request.Leave_Type__c === 'Training') {
                            availableActions.push({ label: 'Add Supporting Documents', name: 'edit' });
                        }
                        if (request.Leave_Type__c === 'Sick Leave') {
                            availableActions.push({ label: 'Add Medical Certificate', name: 'edit' });
                        }
                        if (request.Leave_Type__c !== 'Sick Leave') {
                            availableActions.push({ label: 'Request cancellation', name: 'request_cancellation' });
                        }

                    break;

                case 'Cancellation Requested':
                    availableActions.push(
                        { label: 'Show details', name: 'show_details' },
                        { label: 'Withdraw cancellation request', name: 'withdraw_cancellation' }
                    );
                    break;

                case 'Pending HR Approval':
                case 'Submitted':
                case 'Pending Manager Approval':
                case 'Escalated to Senior Manager':
                    availableActions.push(
                        { label: 'Show details', name: 'show_details' },
                        { label: 'Edit', name: 'edit' },
                        { label: 'Cancel', name: 'cancel' }
                    );
                    break;

                default:
                    availableActions.push({ label: 'Show details', name: 'show_details' });
            }
            return { ...request, RequestNumber: request.Name, statusBadgeClass: 'slds-badge', availableActions };
        });
    }

    showToast(title, message, variant) { this.dispatchEvent(new ShowToastEvent({ title, message, variant })); }
    showSuccess(message) { this.showToast('Success', message, 'success'); }
    showError(message) { this.showToast('Error', message, 'error'); }
}