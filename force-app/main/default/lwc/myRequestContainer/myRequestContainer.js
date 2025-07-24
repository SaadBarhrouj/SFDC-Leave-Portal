import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { publish, subscribe, MessageContext } from 'lightning/messageService';
import getMyLeaves from '@salesforce/apex/LeaveRequestController.getMyLeaves';
import cancelLeaveRequest from '@salesforce/apex/LeaveRequestController.cancelLeaveRequest';
import requestCancellation from '@salesforce/apex/LeaveRequestController.requestCancellation';
import LEAVE_REQUEST_SELECTED_CHANNEL from '@salesforce/messageChannel/LeaveRequestSelectedChannel__c';
import REFRESH_LEAVE_DATA_CHANNEL from '@salesforce/messageChannel/RefreshLeaveDataChannel__c';
import CLEAR_SELECTION_CHANNEL from '@salesforce/messageChannel/ClearSelectionChannel__c';
import LEAVE_DATA_FOR_CALENDAR_CHANNEL from '@salesforce/messageChannel/LeaveDataForCalendarChannel__c';
import withdrawCancellationRequest from '@salesforce/apex/LeaveRequestController.withdrawCancellationRequest';

const COLUMNS = [
    { label: 'Request Number', fieldName: 'Name', type: 'url', typeAttributes: { label: { fieldName: 'RequestNumber' }, target: '_blank' }, sortable: true },
    { label: 'Leave Type', fieldName: 'Leave_Type__c', sortable: true },
    { label: 'Start Date', fieldName: 'Start_Date__c', type: 'date-local', sortable: true },
    { label: 'End Date', fieldName: 'End_Date__c', type: 'date-local', sortable: true },
    { label: 'Days Requested', fieldName: 'Number_of_Days_Requested__c', type: 'number', sortable: true, cellAttributes: { alignment: 'left' } },
    { label: 'Status', fieldName: 'Status__c', type: 'customBadge', typeAttributes: { value: { fieldName: 'Status__c' }, class: { fieldName: 'statusBadgeClass' } }, initialWidth: 220 },
    { type: 'action', typeAttributes: { rowActions: { fieldName: 'availableActions' } } }
];

export default class MyRequestContainer extends LightningElement {
    @track requests = [];
    @track isLoading = false;
    @track selectedStatus = 'All';
    @track showCreateModal = false;
    @track recordIdToEdit = null;
    
    columns = COLUMNS;
    wiredRequestsResult;
    subscriptionClearSelection;
    
    statusOptions = [
        { label: 'All Status', value: 'All' }, { label: 'Approved', value: 'Approved' }, { label: 'Submitted', value: 'Submitted' },
        { label: 'Pending Manager Approval', value: 'Pending Manager Approval' }, { label: 'Pending HR Approval', value: 'Pending HR Approval' },
        { label: 'Escalated to Senior Manager', value: 'Escalated to Senior Manager' }, { label: 'Rejected', value: 'Rejected' },
        { label: 'Cancelled', value: 'Cancelled' }, { label: 'Cancellation Requested', value: 'Cancellation Requested' }
    ];

    @wire(MessageContext) messageContext;

    @wire(getMyLeaves)
    wiredRequests(result) {
        this.wiredRequestsResult = result;
        if (result.data) {
            this.requests = this.processRequestsForDisplay(result.data);
        } else if (result.error) {
            this.showError(result.error?.body?.message || 'Error loading requests.');
        }
    }

    connectedCallback() {
        this.subscribeToClearSelection();
    }

    get filteredRequests() {
        if (this.selectedStatus === 'All') return this.requests;
        return this.requests.filter(r => r.Status__c === this.selectedStatus);
    }

    handleStatusChange(event) {
        this.selectedStatus = event.detail.value;
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

    async refreshRequests() {
        this.isLoading = true;
        try {
            await refreshApex(this.wiredRequestsResult);
        } catch (error) {
            this.showError('Error refreshing data.');
        } finally {
            this.isLoading = false;
        }
    }

    handleRefresh() {
        return refreshApex(this.wiredRequestsResult).finally(() => {
            const payload = {
                context: 'my'
            };
            publish(this.messageContext, LEAVE_DATA_FOR_CALENDAR_CHANNEL, payload);
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
                .catch(error => this.showError(error.body.message))
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
                .catch(error => this.showError(error.body.message))
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
                .catch(error => this.showError(error.body.message))
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
            const recordUrl = `/lightning/r/Leave_Request__c/${request.Id}/view`;
            let availableActions = [];
            switch (request.Status__c) {
                case 'Approved':
                    availableActions.push({ label: 'Show details', name: 'show_details' });
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
                    availableActions.push(
                        { label: 'Show details', name: 'show_details' },
                        { label: 'Cancel', name: 'cancel' } 
                    );
                    break;

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
            return { ...request, Name: recordUrl, RequestNumber: request.Name, statusBadgeClass: 'slds-badge', availableActions };
        });
    }

    showToast(title, message, variant) { this.dispatchEvent(new ShowToastEvent({ title, message, variant })); }
    showSuccess(message) { this.showToast('Success', message, 'success'); }
    showError(message) { this.showToast('Error', message, 'error'); }
}