import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { publish, MessageContext } from 'lightning/messageService';
import LEAVE_REQUEST_SELECTED_CHANNEL from '@salesforce/messageChannel/LeaveRequestSelectedChannel__c';
import LEAVE_DATA_FOR_CALENDAR_CHANNEL from '@salesforce/messageChannel/LeaveDataForCalendarChannel__c';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import LEAVE_REQUEST_OBJECT from '@salesforce/schema/Leave_Request__c';
import REJECTION_REASON_FIELD from '@salesforce/schema/Leave_Request__c.Rejection_Reason__c';
import getTeamRequests from '@salesforce/apex/TeamRequestsController.getTeamRequests';
import approveLeaveRequest from '@salesforce/apex/TeamRequestsController.approveLeaveRequest';
import rejectLeaveRequest from '@salesforce/apex/TeamRequestsController.rejectLeaveRequest';
import CLEAR_SELECTION_CHANNEL from '@salesforce/messageChannel/ClearSelectionChannel__c';
import { subscribe } from 'lightning/messageService';

const ACTIONS = [
    { label: 'Approve', name: 'approve' },
    { label: 'Reject', name: 'reject' }
];

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
    { label: 'Total Days', fieldName: 'Number_of_Days_Requested__c', type: 'number', sortable: true, cellAttributes: { alignment: 'left' } },
    {
        label: 'Status',
        fieldName: 'Status__c',
        type: 'text',
        sortable: true
    },
    {
        type: 'action',
        typeAttributes: { rowActions: ACTIONS },
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
                return {
                    ...req,
                    RequesterName: req.Requester__r.Name,
                    requesterUrl: `/lightning/r/User/${req.Requester__c}/view`,
                    requestUrl: `/lightning/r/Leave_Request__c/${req.Id}/view`
                };
            });
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.requests = [];
            this.showToast('Error', 'Could not retrieve team requests.', 'error');
        }
        this.isLoading = false;
    }

    get hasRequests() {
        return this.requests && this.requests.length > 0;
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
            default:
        }
    }

    handleApprove() {
        this.isLoading = true;
        approveLeaveRequest({ leaveRequestId: this.selectedRequestId })
            .then(() => {
                this.showToast('Success', 'Request approved successfully.', 'success');
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
                this.closeModal();
                return this.refreshData();
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
                this.isLoading = false;
            });
    }

    handleRefresh() {
        this.refreshData();
    }

    refreshData() {
        this.isLoading = true;
        return refreshApex(this.wiredRequestsResult).finally(() => {
            this.isLoading = false;
            const payload = {
                context: 'team'
            };
            publish(this.messageContext, LEAVE_DATA_FOR_CALENDAR_CHANNEL, payload);
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