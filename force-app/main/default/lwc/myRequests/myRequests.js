import { refreshApex } from '@salesforce/apex';
import cancelLeaveRequest from '@salesforce/apex/LeaveRequestController.cancelLeaveRequest';
import getLeaveBalanceId from '@salesforce/apex/LeaveRequestController.getLeaveBalanceId';
import getMyLeaves from '@salesforce/apex/LeaveRequestController.getMyLeaves';
import getNumberOfDaysRequested from '@salesforce/apex/LeaveRequestController.getNumberOfDaysRequested';
import submitForApproval from '@salesforce/apex/LeaveRequestController.submitForApproval';
import CLEAR_SELECTION_CHANNEL from '@salesforce/messageChannel/ClearSelectionChannel__c';
import LEAVE_DATA_FOR_CALENDAR_CHANNEL from '@salesforce/messageChannel/LeaveDataForCalendarChannel__c';
import LEAVE_REQUEST_SELECTED_CHANNEL from '@salesforce/messageChannel/LeaveRequestSelectedChannel__c';
import userId from '@salesforce/user/Id';
import { MessageContext, publish, subscribe } from 'lightning/messageService';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { LightningElement, track, wire } from 'lwc';

const COLUMNS = [
    {
        label: 'Request Number',
        fieldName: 'Name',
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'RequestNumber' },
            target: '_blank'
        },
        sortable: true
    },
    { label: 'Leave Type', fieldName: 'Leave_Type__c', sortable: true },
    { label: 'Start Date', fieldName: 'Start_Date__c', type: 'date-local', sortable: true },
    { label: 'End Date', fieldName: 'End_Date__c', type: 'date-local', sortable: true },
    { label: 'Days Requested', fieldName: 'Number_of_Days_Requested__c', type: 'number', sortable: true, cellAttributes: { alignment: 'left' } },
    {
        label: 'Status',
        fieldName: 'Status__c',
        type: 'text',
        sortable: true,
        cellAttributes: {
            class: { fieldName: 'statusClass' }
            
        }
    },
    { label: 'Comments', fieldName: 'Employee_Comments__c', wrapText: true },
    {
        type: 'action',
        typeAttributes: {
            rowActions: { fieldName: 'availableActions' }
        }
    }
];

export default class MyRequests extends LightningElement {
    @track selectedStatus = 'All';
    @track selectedLeaveType = '';

    @track startDate;
    @track endDate;
    @track numberOfDaysRequested = 0;

    // Wire pour appeler la méthode Apex de manière réactive
    @wire(getNumberOfDaysRequested, { startDate: '$startDate', endDate: '$endDate' })
    wiredCalculatedDays({ error, data }) {
        if (data || data === 0) {
            this.numberOfDaysRequested = data;
        } else if (error) {
            console.error('Error calculating days:', error);
            this.numberOfDaysRequested = 0;
        }
    }
    acceptedFormats = ['.pdf', '.png', '.jpg', '.jpeg'];
    statusOptions = [
        { label: 'All', value: 'All' },
        { label: 'Approved', value: 'Approved' },
        { label: 'Submitted', value: 'Submitted' },
        { label: 'Pending Manager Approval', value: 'Pending Manager Approval' },
        { label: 'Pending HR Approval', value: 'Pending HR Approval' },
        { label: 'Rejected', value: 'Rejected' },
        { label: 'Cancelled', value: 'Cancelled' },
        { label: 'CANCELLATION_REQUESTED', value: 'CANCELLATION_REQUESTED' }
    ];

    handleStatusChange(event) {
        this.selectedStatus = event.detail.value;
    }

    get filteredRequests() {
        if (this.selectedStatus === 'All') {
            return this.requests;
        }
        return this.requests.filter(r => r.Status__c === this.selectedStatus);
    }
    subscriptionClearSelection;
    @track requests = [];
    @track isLoading = false;
    @track showCreateModal = false;
    @track recordIdToEdit = null;
    columns = COLUMNS;

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

    wiredRequestsResult;

    @wire(getMyLeaves)
    wiredRequests(result) {
        this.wiredRequestsResult = result;

        if (result.data) {
            console.log('Data received:', result.data);
            this.requests = this.processRequestsForDisplay(result.data);

        } else if (result.error) {
            console.error('Error loading requests:', result.error);
        }
    }

    get currentUserId() {
        return userId;
    }

    get hasRequests() {
        return this.filteredRequests && this.filteredRequests.length > 0;
    }

    processRequestsForDisplay(rawData) {
        return rawData.map(request => {
            const recordUrl = `/lightning/r/Leave_Request__c/${request.Id}/view`;
            let statusClass = '';
            let availableActions = [];
            switch (request.Status__c) {
                case 'Approved':
                    statusClass = 'slds-text-color_success';
                    availableActions = [
                        { label: 'Show details', name: 'show_details' },
                        { label: 'Request cancellation', name: 'request_cancellation' }
                    ];
                    break;
                case 'CANCELLATION_REQUESTED':
                    statusClass = 'slds-text-color_warning';
                    availableActions = [
                        { label: 'Show details', name: 'show_details' },
                        { label: 'Withdraw cancellation request', name: 'withdraw_cancellation' }
                    ];
                    break;
                case 'Rejected':
                    statusClass = 'slds-text-color_error';
                    availableActions = [{ label: 'Show details', name: 'show_details' }];
                    break;
                case 'Pending':
                case 'Submitted':
                case 'Pending Manager Approval':
                case 'Pending HR Approval':
                    statusClass = 'slds-text-color_weak';
                    availableActions = [
                        { label: 'Show details', name: 'show_details' },
                        { label: 'Edit', name: 'edit' },
                        { label: 'Cancel', name: 'cancel' }
                    ];
                    break;
                case 'Cancelled':
                    statusClass = 'slds-text-color_weak';
                    availableActions = [{ label: 'Show details', name: 'show_details' }];
                    break;
                default:
                    statusClass = 'slds-text-color_default';
                    availableActions = [{ label: 'Show details', name: 'show_details' }];
            }

            return {
                ...request,
                Name: recordUrl,
                RequestNumber: request.Name,
                statusClass: statusClass,
                availableActions: availableActions
            };
        });
    }

    handleNewRequest() {
        console.log('New Request clicked');
        this.recordIdToEdit = null;
        this.selectedLeaveType = '';
        this.startDate = null;
        this.endDate = null;
        this.numberOfDaysRequested = 0;
        this.showCreateModal = true;
    }

    closeCreateModal() {
        console.log('Create modal closed');
        this.showCreateModal = false;
        this.recordIdToEdit = null;
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        if (selectedRows.length === 1) {
            const payload = {
                recordId: selectedRows[0].Id,
                context: 'myRequest'
            };
            console.log('[myRequests] Publishing row selection:', {
                recordId: selectedRows[0].Id,
                context: 'myRequest'
            });
            publish(this.messageContext, LEAVE_REQUEST_SELECTED_CHANNEL, payload);
        } else {
            console.log('[myRequests] No row selected or multiple rows selected:', selectedRows);
        }
    }

    clearSelection() {
        const datatable = this.template.querySelector('lightning-datatable');
        if (datatable) {
            datatable.selectedRows = [];
        }
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        switch (actionName) {
            case 'show_details':
                this.showRowDetails(row);
                break;
            case 'cancel':
                this.cancelRequest(row);
                break;
            case 'edit':
                this.editRequest(row);
                break;
            default:
        }
    }

    showRowDetails(row) {
        const payload = {
            recordId: row.Id,
            context: 'myRequest'
        };
        console.log('[myRequests] Publishing show details:', payload);
        publish(this.messageContext, LEAVE_REQUEST_SELECTED_CHANNEL, payload);
    }

    get modalTitle() {
        return this.recordIdToEdit ? 'Edit Leave Request' : 'New Leave Request';
    }

    editRequest(row) {
        console.log('Edit request:', row);
        this.recordIdToEdit = row.Id;
        this.showCreateModal = true;
        this.selectedLeaveType = row.Leave_Type__c;
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

                    this.showError(error.body.message);
                })
                .finally(() => {
                    this.isLoading = false;
                });
        }
    }

    async refreshRequests() {
        console.log('Refreshing data');
        this.isLoading = true;
        try {
            await refreshApex(this.wiredRequestsResult);
        } catch (error) {
            console.error('Error refreshing data:', error);
        } finally {
            this.isLoading = false;
            const payload = {
                context: 'my'
            };
            publish(this.messageContext, LEAVE_DATA_FOR_CALENDAR_CHANNEL, payload);
        }
    }

    async handleSubmit(event) {
        event.preventDefault();
        console.log('Submit form');
    
        const fields = event.detail.fields;
        const leaveType = fields.Leave_Type__c;
    
        try {
            // Pour les types qui nécessitent un solde
            let leaveBalanceId = null;
            if (leaveType !== 'Sick Leave' && leaveType !== 'Training') {
                leaveBalanceId = await getLeaveBalanceId({
                    employeeId: userId,
                    leaveType: leaveType
                });
                fields.Leave_Balance__c = leaveBalanceId;
            }
    
            fields.Requester__c = userId;
            fields.Status__c = 'Submitted';
    
            this.refs.leaveRequestForm.submit(fields);
    
        } catch (error) {
            console.error('Error finding leave balance:', error);
            this.showError('Could not find leave balance for ' + leaveType + '. Please contact your administrator.');
        }
    }

    handleSuccess(event) {
        const message = this.recordIdToEdit
            ? 'Leave request updated successfully!'
            : 'Leave request created successfully!';

        console.log(message, 'ID:', event.detail.id);

        if (!this.recordIdToEdit) {
            submitForApproval({ requestId: event.detail.id })
                .then(result => {
                    this.showSuccess(result);
                    this.refreshRequests();
                })
                .catch(error => {
                    this.showError(error.body.message);
                });
        } else {
            this.showSuccess(message);
            this.refreshRequests();
        }

        this.closeCreateModal();
    }

    handleError(event) {
        console.error('Error creating leave request:', event.detail);

        const errorMessage =
            event.detail?.detail ??
            event.detail?.message ??
            event.detail?.output?.errors?.[0]?.message ??
            'Unknown error occurred';

        this.showError('Error creating leave request: ' + errorMessage);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }

    showSuccess(message) {
        this.showToast('Success', message, 'success');
    }

    showError(message) {
        this.showToast('Error', message, 'error');
    }

    get isDocumentRequired() {
        if (this.selectedLeaveType === 'Training') {
            return true;
        }
        if (this.selectedLeaveType === 'Sick Leave' && this.numberOfDaysRequested > 2) {
            return true;
        }
        return false;
    }

    handleFieldChange(event) {
        const fieldName = event.target.fieldName;
        const value = event.target.value;

        if (fieldName === 'Leave_Type__c') {
            this.selectedLeaveType = value;
        } else if (fieldName === 'Start_Date__c') {
            if (this.endDate && value > this.endDate) {
                this.endDate = null; 
            }
            this.startDate = value;
        } else if (fieldName === 'End_Date__c') {
            this.endDate = value;
        }
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        this.showSuccess(`${uploadedFiles.length} fichier(s) déposé(s) avec succès.`);
        // Le Flow s'occupera de la mise à jour du statut justificatif.
    }

    getRequestedDays() {
        // Méthode utilitaire pour récupérer le nombre de jours demandés dans le formulaire
        const form = this.template.querySelector('lightning-record-edit-form');
        if (form) {
            const daysField = form.querySelector('[field-name="Number_of_Days_Requested__c"]');
            return daysField ? Number(daysField.value) : 0;
        }
        return 0;
    }
}