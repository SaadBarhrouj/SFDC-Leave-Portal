import { refreshApex } from '@salesforce/apex';
import approveLeaveRequest from '@salesforce/apex/TeamRequestsController.approveLeaveRequest';
import getTeamRequests from '@salesforce/apex/TeamRequestsController.getTeamRequests';
import rejectLeaveRequest from '@salesforce/apex/TeamRequestsController.rejectLeaveRequest';
import CLEAR_SELECTION_CHANNEL from '@salesforce/messageChannel/ClearSelectionChannel__c';
import LEAVE_DATA_FOR_CALENDAR_CHANNEL from '@salesforce/messageChannel/LeaveDataForCalendarChannel__c';
import LEAVE_REQUEST_MODIFIED_CHANNEL from '@salesforce/messageChannel/LeaveRequestModifiedChannel__c';
import LEAVE_REQUEST_SELECTED_CHANNEL from '@salesforce/messageChannel/LeaveRequestSelectedChannel__c';
import LEAVE_REQUEST_OBJECT from '@salesforce/schema/Leave_Request__c';
import REJECTION_REASON_FIELD from '@salesforce/schema/Leave_Request__c.Rejection_Reason__c';
import { MessageContext, publish, subscribe } from 'lightning/messageService';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import { LightningElement, track, wire } from 'lwc';

const BASE_ACTIONS = [
    { label: 'Show details', name: 'show_details' },
    { label: 'Approve', name: 'approve' },
    { label: 'Reject', name: 'reject' },
];

function getStatusClass(status) {
    switch (status) {
        default:
            return 'slds-badge slds-badge';
    }
}

const COLUMNS = [
    {
        label: 'Requester',
        fieldName: 'requesterUrl',
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'RequesterName' },
            target: '_self'
        }
    },
    { label: 'Request Name', fieldName: 'Name', type: 'button', typeAttributes: { label: { fieldName: 'RequestName' }, name: 'show_details', variant: 'base' } },
    { label: 'Leave Type', fieldName: 'Leave_Type__c' },
    { label: 'Start Date', fieldName: 'Start_Date__c', type: 'date-local' },
    { label: 'End Date', fieldName: 'End_Date__c', type: 'date-local' },
    { label: 'Days Requested', fieldName: 'Number_of_Days_Requested__c', type: 'number',  cellAttributes: { alignment: 'left' } },
    {
        label: 'Status',
        fieldName: 'Status__c',
        type: 'customBadge',
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

const DEFAULT_FILTERS = {
    status: 'All',
    requesterName: '',
    leaveType: '',
    startDate: null,
    endDate: null
};

export default class TeamRequests extends LightningElement {
    @track columns = COLUMNS;
    allRequests = [];
    @track filteredData = [];
    @track rejectionReasonOptions = [];
    wiredRequestsResult;
    subscriptionClearSelection;

    isLoading = true;
    error;

    showFilterPopover = false;
    selectedRequestId;
    showModal = false;
    rejectionReason = '';
    approverComment = '';

    @track filterValues = { ...DEFAULT_FILTERS };

    statusOptions = [
        { label: 'All Statuses', value: 'All' },
        { label: 'Pending Manager Approval', value: 'Pending Manager Approval' },
        { label: 'Pending HR Approval', value: 'Pending HR Approval' },
        { label: 'Escalated to Senior Manager', value: 'Escalated to Senior Manager' },
        { label: 'Cancellation Requested', value: 'Cancellation Requested' }
    ];

    leaveTypeOptions = [
        { label: 'All Types', value: '' },
        { label: 'Paid Leave', value: 'Paid Leave' },
        { label: 'RTT', value: 'RTT' },
        { label: 'Sick Leave', value: 'Sick Leave' },
        { label: 'Training', value: 'Training' },
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
            this.allRequests = result.data.map(req => {
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
                const requesterName = req.Requester__r ? req.Requester__r.Name : '';
                return {
                    ...req,
                    RequesterName: requesterName,
                    requesterUrl: `/lightning/r/User/${req.Requester__c}/view`,
                    RequestName: req.Name,
                    ManagerName: managerName,
                    ManagerId: req.Requester__r ? req.Requester__r.ManagerId : '',
                    managerUrl,
                    rowActions,
                    statusBadgeClass: getStatusClass(req.Status__c)
                };
            });
            this.applyFilters();
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.allRequests = [];
            this.filteredData = [];
            console.error('TeamRequests error:', JSON.stringify(result.error));
            this.showToast('Error', 'Could not retrieve team requests.', 'error');
        }
        this.isLoading = false;
    }

    get hasRequests() {
        return this.filteredData && this.filteredData.length > 0;
    }

    get filterButtonVariant() {
        return this.showFilterPopover ? 'brand' : 'neutral';
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
        let data = [...this.allRequests];
        const { status, requesterName, leaveType, startDate, endDate } = this.filterValues;

        if (status && status !== 'All') {
            data = data.filter(req => req.Status__c === status);
        }
        if (requesterName) {
            const lowerCaseName = requesterName.toLowerCase();
            data = data.filter(req => req.RequesterName && req.RequesterName.toLowerCase().includes(lowerCaseName));
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
        this.filteredData = data;
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
                if (row.Status__c === 'Cancellation Requested') {
                    this.handleRejectCancellation();
                } else {
                    this.openRejectModal();
                }
                break;
            case 'show_details':
                publish(this.messageContext, LEAVE_REQUEST_SELECTED_CHANNEL, {
                    recordId: row.Id,
                    context: 'teamRequest'
                });
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

    handleRejectCancellation() {
        if (confirm('Are you sure you want to reject this cancellation request? The leave will remain approved.')) {
            this.isLoading = true;

            rejectLeaveRequest({
                leaveRequestId: this.selectedRequestId,
                rejectionReason: null,
                approverComment: null,
                isReasonRequired: false
            })
                .then(() => {
                    this.showToast('Success', 'Cancellation request rejected.', 'success');
                    return this.refreshData();
                })
                .catch(error => {
                    this.showToast('Error', error.body.message, 'error');
                    this.isLoading = false;
                });
        }
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
        this.isLoading = true;

        rejectLeaveRequest({
            leaveRequestId: this.selectedRequestId,
            rejectionReason: this.rejectionReason,
            approverComment: this.approverComment,
            isReasonRequired: true
        })
            .then(() => {
                this.showToast('Success', 'Request rejected successfully.', 'success');
                this.closeModal();
                return this.refreshData();
            })
            .catch(error => {
                console.error('Error Details:', JSON.stringify(error));

                let errorMessage = 'An unknown error occurred.';

                if (error && error.body && error.body.fieldErrors && error.body.fieldErrors.Approver_Comments__c) {

                    errorMessage = error.body.fieldErrors.Approver_Comments__c[0].message;

                    let commentField = this.template.querySelector('[data-field="Approver_Comments__c"]');
                    if (commentField) {
                        commentField.setCustomValidity(errorMessage);
                        commentField.reportValidity();
                    }

                } else if (error && error.body && error.body.message) {
                    errorMessage = error.body.message;
                    this.showToast('Error', errorMessage, 'error');
                }

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
        let displayMessage = message;

        if (typeof displayMessage === 'string' && displayMessage.includes('FIELD_CUSTOM_VALIDATION_EXCEPTION')) {
            const parts = displayMessage.split('FIELD_CUSTOM_VALIDATION_EXCEPTION,');
            if (parts.length > 1) {
                displayMessage = parts[1].split(':')[0].trim();
            }
        }

        const event = new ShowToastEvent({
            title: title,
            message: displayMessage,
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