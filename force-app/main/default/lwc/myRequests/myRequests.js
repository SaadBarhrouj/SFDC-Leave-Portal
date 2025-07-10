import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import userId from '@salesforce/user/Id';
import getLeaveBalanceId from '@salesforce/apex/LeaveRequestController.getLeaveBalanceId';
import getMyLeaves from '@salesforce/apex/LeaveRequestController.getMyLeaves';

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
    { label: 'Days Requested', fieldName: 'Number_of_Days_Requested__c', type: 'number', sortable: true },
    { 
        label: 'Status', 
        fieldName: 'Status__c',
        type: 'text',
        sortable: true,
        cellAttributes: {
            class: { fieldName: 'statusClass' }
        }
    },
    { label: 'Comments', fieldName: 'Employee_Comments__c', wrapText: true }
];

export default class MyRequests extends LightningElement {
    @track requests = [];
    @track isLoading = false;
    @track showCreateModal = false;
    
    columns = COLUMNS;
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
        return this.requests && this.requests.length > 0;
    }

    processRequestsForDisplay(rawData) {
        return rawData.map(request => {
            const recordUrl = `/lightning/r/Leave_Request__c/${request.Id}/view`;
            let statusClass = '';

            switch(request.Status__c) {
                case 'Approved':
                    statusClass = 'slds-text-color_success';
                    break;
                case 'Rejected':
                    statusClass = 'slds-text-color_error';
                    break;
                case 'Pending':
                case 'Submitted':
                    statusClass = 'slds-text-color_weak';
                    break;
                case 'Cancelled':
                    statusClass = 'slds-text-color_weak';
                    break;
                default:
                    statusClass = 'slds-text-color_default';
            }

            return {
                ...request,
                Name: recordUrl,
                RequestNumber: request.Name,
                statusClass: statusClass
            };
        });
    }

    handleNewRequest() {
        console.log('New Request clicked');
        this.showCreateModal = true;
    }

    closeCreateModal() {
        console.log('Create modal closed');
        this.showCreateModal = false;
    }

    async handleRefresh() {
        console.log('Refresh data');
        this.isLoading = true;
        try {
            await refreshApex(this.wiredRequestsResult);
            this.showSuccess('Data refreshed successfully!');
        } catch (error) {
            console.error('Error refreshing data:', error);
            this.showError('Failed to refresh data. Please try again.');
        } finally {
            this.isLoading = false;
        }
    }

    async refreshData() {
        console.log('Auto refresh data');
        this.isLoading = true;
        try {
            await refreshApex(this.wiredRequestsResult);
        } catch (error) {
            console.error('Error refreshing data:', error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleSubmit(event) {
        event.preventDefault();
        console.log('Submit form');
        
        const fields = event.detail.fields;
        
        try {
            const leaveBalanceId = await getLeaveBalanceId({
                employeeId: userId,
                leaveType: fields.Leave_Type__c
            });
            
            fields.Requester__c = userId;
            fields.Leave_Balance__c = leaveBalanceId;
            fields.Status__c = 'Submitted';
            
            this.refs.leaveRequestForm.submit(fields);
            
        } catch (error) {
            console.error('Error finding leave balance:', error);
            this.showError('Could not find leave balance for ' + fields.Leave_Type__c + '. Please contact your administrator.');
        }
    }

    handleSuccess(event) {
        console.log('Leave request created successfully with ID:', event.detail.id);
        
        this.closeCreateModal();
        this.showSuccess('Leave request created successfully!');
        this.refreshData();
    }

    handleError(event) {
        console.error('Error creating leave request:', event.detail);
        
        let errorMessage = 'Unknown error occurred';
        
        if (event.detail && event.detail.detail) {
            errorMessage = event.detail.detail;
        } else if (event.detail && event.detail.message) {
            errorMessage = event.detail.message;
        } else if (event.detail && event.detail.output && event.detail.output.errors) {
            const errors = event.detail.output.errors;
            if (errors.length > 0) {
                errorMessage = errors[0].message;
            }
        }
        
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
}