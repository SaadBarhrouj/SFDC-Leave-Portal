import { refreshApex } from '@salesforce/apex';
import approveLeaveRequest from '@salesforce/apex/TeamRequestsController.approveLeaveRequest';
import getTeamRequests from '@salesforce/apex/TeamRequestsController.getTeamRequests';
import rejectLeaveRequest from '@salesforce/apex/TeamRequestsController.rejectLeaveRequest';
import CLEAR_SELECTION_CHANNEL from '@salesforce/messageChannel/ClearSelectionChannel__c';
import LEAVE_DATA_FOR_CALENDAR_CHANNEL from '@salesforce/messageChannel/LeaveDataForCalendarChannel__c';
import LEAVE_REQUEST_SELECTED_CHANNEL from '@salesforce/messageChannel/LeaveRequestSelectedChannel__c';
import LEAVE_REQUEST_MODIFIED_CHANNEL from '@salesforce/messageChannel/LeaveRequestModifiedChannel__c';
import LEAVE_REQUEST_OBJECT from '@salesforce/schema/Leave_Request__c';
import REJECTION_REASON_FIELD from '@salesforce/schema/Leave_Request__c.Rejection_Reason__c';
import { MessageContext, publish, subscribe } from 'lightning/messageService';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import { LightningElement, track, wire } from 'lwc';

const BASE_ACTIONS = [
    { label: 'Approve', name: 'approve' },
    { label: 'Reject', name: 'reject' }
];

function getStatusClass(status) {
    switch (status) {
        /* case 'Approved':
            return 'slds-badge slds-theme_success';
        case 'Rejected':
            return 'slds-badge slds-theme_error';
        case 'Cancelled':
            return 'slds-badge slds-theme_warning';
        case 'Cancellation Requested':
            return 'slds-badge slds-badge_inverse';
        case 'Submitted':
        case 'Pending Manager Approval':
        case 'Pending HR Approval':
        case 'Escalated to Senior Manager':
            return 'slds-badge'; */
        default:
            return 'slds-badge slds-badge';
    }
}

const COLUMNS = [
    {
        label: 'Requester',
        fieldName: 'requesterUrl',
        type: 'url',
        sortable: true,
        typeAttributes: {
            label: { fieldName: 'RequesterName' },
            target: '_self'
        }
    },
    {
        label: 'Request ID',
        fieldName: 'requestUrl',
        type: 'url',
        sortable: true,
        typeAttributes: {
            label: { fieldName: 'Name' },
            target: '_self'
        }
    },
    { label: 'Leave Type', fieldName: 'Leave_Type__c', sortable: true },
    { label: 'Start Date', fieldName: 'Start_Date__c', type: 'date-local', sortable: true },
    { label: 'End Date', fieldName: 'End_Date__c', type: 'date-local', sortable: true },
    { label: 'Days Requested', fieldName: 'Number_of_Days_Requested__c', type: 'number', sortable: true, cellAttributes: { alignment: 'left' } },
    {
        label: 'Status',
        fieldName: 'Status__c',
        type: 'customBadge',
        sortable: true,
        typeAttributes: {
            value: { fieldName: 'Status__c' },
            class: { fieldName: 'statusBadgeClass' }
        },
        initialWidth: 220
    },
    {
        label: 'Manager',
        fieldName: 'managerUrl',
        type: 'url',
        sortable: true,
        typeAttributes: {
            label: { fieldName: 'ManagerName' },
            target: '_self'
        }
    },
    {
        type: 'action',
        typeAttributes: { rowActions: { fieldName: 'rowActions' } },
    },
];

export default class TeamRequests extends LightningElement {
    @track columns = COLUMNS;
    @track requests = [];
    @track rejectionReasonOptions = [];
    wiredRequestsResult;
    subscriptionClearSelection;

    isLoading = true;
    error;

    showModal = false;
    selectedRequestId;
    rejectionReason = '';
    approverComment = '';

    @track selectedStatus = 'All';
    statusOptions = [
        { label: 'All Status', value: 'All' },
        { label: 'Pending Manager Approval', value: 'Pending Manager Approval' },
        { label: 'Pending HR Approval', value: 'Pending HR Approval' },
        { label: 'Escalated to Senior Manager', value: 'Escalated to Senior Manager' },
        { label: 'Cancellation Requested', value: 'Cancellation Requested' }
    ];

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        this.subscribeToClearSelection();
    }

    subscribeToClearSelection() {
        if (!this.subscriptionClearSelection) {
            this.subscriptionClearSelection = subscribe(
                this.messageContext,
                CLEAR_SELECTION_CHANNEL,
                () => this.clearSelection()
            );
        }
    }

    @wire(getObjectInfo, { objectApiName: LEAVE_REQUEST_OBJECT })
    objectInfo;

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: REJECTION_REASON_FIELD })
    wiredPicklistValues({ error, data }) {
        if (data) {
            this.rejectionReasonOptions = data.values;
        } else if (error) {
            this.showToast('Error', 'Could not load rejection reasons.', 'error');
        }
    }

    @wire(getTeamRequests)
    wiredRequests(result) {
        this.isLoading = true;
        this.wiredRequestsResult = result;
        if (result.data) {
            this.requests = result.data.map(req => {
                let rowActions = [...BASE_ACTIONS];
                if (req.Status__c === 'Pending HR Approval' || req.Status__c === 'Escalated to Senior Manager') {
                    rowActions.push({ label: "View manager's team calendar", name: 'view_manager_calendar' });
                }
                if (req.Status__c === 'Pending Manager Approval') {
                    rowActions.push({ label: "View in my team calendar", name: 'view_manager_calendar' });
                }
                let managerName = '';
                let managerUrl = '';
                if (req.Requester__r && req.Requester__r.Manager && req.Requester__r.Manager.Name) {
                    managerName = req.Requester__r.Manager.Name;
                    managerUrl = `/lightning/r/User/${req.Requester__r.ManagerId}/view`;
                } else {
                    managerName = 'No manager';
                    managerUrl = '';
                }
                return {
                    ...req,
                    RequesterName: req.Requester__r.Name,
                    requesterUrl: `/lightning/r/User/${req.Requester__c}/view`,
                    requestUrl: `/lightning/r/Leave_Request__c/${req.Id}/view`,
                    ManagerName: managerName,
                    ManagerId: req.Requester__r.ManagerId,
                    managerUrl,
                    rowActions,
                    statusBadgeClass: getStatusClass(req.Status__c)
                };
            });
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.requests = [];
            console.error('TeamRequests error:', JSON.stringify(result.error));
            this.showToast('Error', 'Could not retrieve team requests.', 'error');
        }
        this.isLoading = false;
    }

    get filteredRequests() {
        if (this.selectedStatus === 'All') {
            return this.requests;
        }
        return this.requests.filter(r => r.Status__c === this.selectedStatus);
    }

    get hasRequests() {
        return this.filteredRequests && this.filteredRequests.length > 0;
    }

    handleStatusChange(event) {
        this.selectedStatus = event.detail.value;
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        if (selectedRows.length === 1) {
            const payload = {
                recordId: selectedRows[0].Id,
                context: 'teamRequest'
            };
            publish(this.messageContext, LEAVE_REQUEST_SELECTED_CHANNEL, payload);
        }
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        this.selectedRequestId = row.Id;

        switch (actionName) {
            case 'approve':
                this.handleApprove();
                break;
            case 'reject':
                this.openRejectModal();
                break;
            case 'view_manager_calendar':
                if (row.ManagerId) {
                    const payload = {
                        managerId: row.ManagerId,
                        context: 'managerTeam',
                        selectedRequestId: row.Id 
                    };
                    publish(this.messageContext, LEAVE_DATA_FOR_CALENDAR_CHANNEL, payload);
                }
                break;
            default:
        }
    }

    handleApprove() {
        this.isLoading = true;
        approveLeaveRequest({ leaveRequestId: this.selectedRequestId })
            .then(() => {
                this.showToast('Success', 'Request approved successfully.', 'success');
                publish(this.messageContext, LEAVE_REQUEST_MODIFIED_CHANNEL, {});
                return this.refreshData();
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
                this.isLoading = false;
            });
    }

    openRejectModal() {
        this.showModal = true;
    }

    closeModal() {
        this.showModal = false;
        this.rejectionReason = '';
        this.approverComment = '';
        this.selectedRequestId = null;
    }

    handleReasonChange(event) {
        this.rejectionReason = event.target.value;
    }

    handleCommentChange(event) {
        this.approverComment = event.target.value;
    }

    submitRejection() {
        if (!this.rejectionReason) {
            this.showToast('Required', 'Please select a reason for rejection.', 'warning');
            return;
        }
        this.isLoading = true;
        rejectLeaveRequest({
            leaveRequestId: this.selectedRequestId,
            rejectionReason: this.rejectionReason,
            approverComment: this.approverComment
        })
            .then(() => {
                this.showToast('Success', 'Request rejected successfully.', 'success');
                publish(this.messageContext, LEAVE_REQUEST_MODIFIED_CHANNEL, {});
                this.closeModal();
                return this.refreshData();
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
                this.isLoading = false;
            });
    }

    handleRefresh() {
        this.isLoading = true;
        return refreshApex(this.wiredRequestsResult).finally(() => {
            this.isLoading = false;
            const payload = {
                context: 'team'
            };
            publish(this.messageContext, LEAVE_DATA_FOR_CALENDAR_CHANNEL, payload);
        });
    }

    refreshData() {
        this.isLoading = true;
        return refreshApex(this.wiredRequestsResult).finally(() => {
            this.isLoading = false;
        });
    }

    showToast(title, message, type) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: type
        });
        this.dispatchEvent(event);
    }
     
    clearSelection() {
        const datatable = this.template.querySelector('lightning-datatable');
        if (datatable) {
            datatable.selectedRows = [];
        }
    }
}