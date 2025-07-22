import { refreshApex } from '@salesforce/apex';
import cancelLeaveRequest from '@salesforce/apex/LeaveRequestController.cancelLeaveRequest';
import getLeaveBalanceId from '@salesforce/apex/LeaveRequestController.getLeaveBalanceId';
import getMyLeaves from '@salesforce/apex/LeaveRequestController.getMyLeaves';
import getNumberOfDaysRequested from '@salesforce/apex/LeaveRequestController.getNumberOfDaysRequested';
import requestCancellation from '@salesforce/apex/LeaveRequestController.requestCancellation';
import CLEAR_SELECTION_CHANNEL from '@salesforce/messageChannel/ClearSelectionChannel__c';
import LEAVE_DATA_FOR_CALENDAR_CHANNEL from '@salesforce/messageChannel/LeaveDataForCalendarChannel__c';
import LEAVE_REQUEST_SELECTED_CHANNEL from '@salesforce/messageChannel/LeaveRequestSelectedChannel__c';
import userId from '@salesforce/user/Id';
import { MessageContext, publish, subscribe } from 'lightning/messageService';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { LightningElement, track, wire } from 'lwc';

function getStatusClass(value) {
    switch (value) {
        /* case 'Approved':
            return 'slds-badge slds-theme_success';
        case 'Rejected':
            return 'slds-badge slds-theme_error';
        case 'Cancellation Requested':
            return 'slds-badge slds-theme_info';
        case 'Cancelled':
        case 'Pending Manager Approval':
        case 'Pending HR Approval':
        case 'Submitted':
        case 'Pending':
            return 'slds-badge'; */
        default:
            return 'slds-badge';
    }
}

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
        type: 'customBadge',
        typeAttributes: {
            value: { fieldName: 'Status__c' },
            class: { fieldName: 'statusBadgeClass' }
        },
        initialWidth: 220
    },
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
        { label: 'All Status', value: 'All' },
        { label: 'Approved', value: 'Approved' },
        { label: 'Submitted', value: 'Submitted' },
        { label: 'Pending Manager Approval', value: 'Pending Manager Approval' },
        { label: 'Pending HR Approval', value: 'Pending HR Approval' },
        { label: 'Escalated to Senior Manager', value: 'Escalated to Senior Manager' },
        { label: 'Rejected', value: 'Rejected' },
        { label: 'Cancelled', value: 'Cancelled' },
        { label: 'Cancellation Requested', value: 'Cancellation Requested' }
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
    @track showUploadStep = false; // Nouvelle propriété pour l'étape 2
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
                    if (request.Leave_Type__c === 'Sick Leave') {
                        availableActions = [
                            { label: 'Show details', name: 'show_details' }
                        ];
                    } else {
                        availableActions = [
                            { label: 'Show details', name: 'show_details' },
                            { label: 'Request cancellation', name: 'request_cancellation' }
                        ];
                    }
                    break;
                case 'Cancellation Requested':
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
                case 'Escalated to Senior Manager':
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
                statusBadgeClass: getStatusClass(request.Status__c),
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
        this.showUploadStep = false; // Réinitialiser à l'ouverture
        this.showCreateModal = true;
    }

    closeCreateModal() {
        console.log('Create modal closed');
        this.showCreateModal = false;
        this.recordIdToEdit = null;
        this.showUploadStep = false; // Réinitialiser à la fermeture
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
            case 'request_cancellation':
                this.requestCancellation(row);
                break;
            case 'edit':
                this.editRequest(row);
                break;
            default:
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
                    console.log('Error requesting cancellation:', error);
                    this.showError(error.body.message);
                })
                .finally(() => {
                    this.isLoading = false;
                });
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
        if (this.recordIdToEdit && this.showUploadStep) {
            return 'Upload Supporting Document';
        }
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
            this.selectedStatus = 'All';
        }
    }
    

    async handleSubmit(event) {
        event.preventDefault();
        console.log('Submit form');
    
        const fields = event.detail.fields;
        const leaveType = fields.Leave_Type__c;
    
        try {
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
        const newRecordId = event.detail.id;
        const isNewRecord = !this.recordIdToEdit;

        // Si nouvelle demande ET justificatif requis, passer à l'étape 2
        if (isNewRecord && this.isDocumentRequired) {
            this.showToast('Success', 'Step 1 complete: Request created!', 'success');
            this.recordIdToEdit = newRecordId;
            this.showUploadStep = true;
            this.refreshRequests();
            return; // Ne pas fermer la modale
        }

        // Cas normal (édition ou création sans justificatif)
        const message = isNewRecord
            ? 'Leave request created successfully!'
            : 'Leave request updated successfully!';

        this.showSuccess(message);
        this.refreshRequests();
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
        if (this.selectedLeaveType === 'Training' || this.selectedLeaveType === 'Sick Leave') {
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