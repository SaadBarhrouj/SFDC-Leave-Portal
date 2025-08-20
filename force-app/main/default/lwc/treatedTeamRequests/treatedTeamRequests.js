import { LightningElement, wire, track } from 'lwc';
import getAllTeamRequestsLog from '@salesforce/apex/TeamRequestsController.getAllTeamRequestsLog';
import { refreshApex } from '@salesforce/apex';
import { publish, MessageContext } from 'lightning/messageService';
import LEAVE_REQUEST_SELECTED_CHANNEL from '@salesforce/messageChannel/LeaveRequestSelectedChannel__c';

function getStatusClass(status) {
    switch (status) {
        default:
            return 'slds-badge';
    }
}

const COLUMNS = [
    { label: 'Requester', fieldName: 'requesterUrl', type: 'url', typeAttributes: { label: { fieldName: 'RequesterName' }, target: '_self' }},
    { label: 'Request Name', fieldName: 'Name', type: 'button', typeAttributes: { label: { fieldName: 'RequestName' }, name: 'show_details', variant: 'base' } },
    { label: 'Leave Type', fieldName: 'Leave_Type__c' },
    { label: 'Start Date', fieldName: 'Start_Date__c', type: 'date-local' },
    { label: 'End Date', fieldName: 'End_Date__c', type: 'date-local' },
    { label: 'Days Requested', fieldName: 'Number_of_Days_Requested__c', type: 'number', cellAttributes: { alignment: 'left' } },
    { label: 'Status', fieldName: 'Status__c', type: 'customBadge', typeAttributes: { value: { fieldName: 'Status__c' }, class: { fieldName: 'statusBadgeClass' }}},
    { type: 'action', typeAttributes: { rowActions: [{ label: 'Show details', name: 'show_details' }] } }
];

const DEFAULT_FILTERS = {
    status: '',
    requesterName: '',
    leaveType: '',
    startDate: null,
    endDate: null
};

export default class TreatedTeamRequests extends LightningElement {
    @track allRequests = [];
    @track filteredRequests = [];
    columns = COLUMNS;
    isLoading = true;
    wiredRequestsResult;
    showFilterPopover = false;
    @track filterValues = { ...DEFAULT_FILTERS };

    statusOptions = [
        { label: 'All Statuses', value: '' },
        { label: 'Submitted', value: 'Submitted' },
        { label: 'Pending Manager Approval', value: 'Pending Manager Approval' },
        { label: 'Pending HR Approval', value: 'Pending HR Approval' },
        { label: 'Escalated to Senior Manager', value: 'Escalated to Senior Manager' },
        { label: 'Approved', value: 'Approved' },
        { label: 'Rejected', value: 'Rejected' },
        { label: 'Cancelled', value: 'Cancelled' },
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

    @wire(getAllTeamRequestsLog)
    wiredRequests(result) {
        this.isLoading = true;
        this.wiredRequestsResult = result;
        if (result.data) {
            this.allRequests = result.data.map(req => ({
                ...req,
                RequesterName: req.Requester__r ? req.Requester__r.Name : '',
                requesterUrl: `/lightning/r/User/${req.Requester__c}/view`,
                RequestName: req.Name,
                statusBadgeClass: getStatusClass(req.Status__c)
            }));
            this.applyFilters();
        } else if (result.error) {
            console.error('Error fetching all team requests log:', result.error);
        }
        this.isLoading = false;
    }

    get hasRequests() {
        return this.filteredRequests && this.filteredRequests.length > 0;
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

        if (status) {
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
        this.filteredRequests = data;
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === 'show_details') {
            publish(this.messageContext, LEAVE_REQUEST_SELECTED_CHANNEL, {
                recordId: row.Id,
                context: 'teamRequest'
            });
        }
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

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredRequestsResult).finally(() => {
            this.isLoading = false;
        });
    }
}