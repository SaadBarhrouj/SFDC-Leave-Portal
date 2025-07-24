import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import userId from '@salesforce/user/Id';
import getNumberOfDaysRequested from '@salesforce/apex/LeaveRequestController.getNumberOfDaysRequested';
import getLeaveBalanceId from '@salesforce/apex/LeaveRequestController.getLeaveBalanceId';
import getRelatedFiles from '@salesforce/apex/LeaveRequestDetailController.getRelatedFiles';
import deleteRelatedFile from '@salesforce/apex/LeaveRequestDetailController.deleteRelatedFile';

export default class LeaveRequestFormModal extends NavigationMixin(LightningElement) {
    _recordId;

    @track selectedLeaveType = '';
    @track startDate;
    @track endDate;
    @track numberOfDaysRequested = 0;
    @track showUploadStep = false;
    @track relatedFiles = [];
    @track isSaving = false;
    
    acceptedFormats = ['.pdf', '.png', '.jpg', '.jpeg'];

    @api
    set recordIdToEdit(value) {
        this._recordId = value;
        if (value) {
            this.loadRelatedFiles(value);
        } else {
            this.relatedFiles = [];
            this.selectedLeaveType = '';
        }
    }
    get recordIdToEdit() {
        return this._recordId;
    }

    @wire(getNumberOfDaysRequested, { startDate: '$startDate', endDate: '$endDate' })
    wiredDays({ error, data }) {
        if (data || data === 0) this.numberOfDaysRequested = data;
        else if (error) this.numberOfDaysRequested = 0;
    }
    
    get currentUserId() { return userId; }
    get isNewRecord() { return !this.recordIdToEdit; }
    get modalTitle() {
        if (this.showUploadStep) return 'Upload Supporting Document';
        return this.isNewRecord ? 'New Leave Request' : 'Edit Leave Request';
    }

    // Dans leaveRequestFormModal.js

    get submitButtonLabel() { if (this.isSaving) {return 'Saving...'; } return this.isNewRecord ? 'Submit Request' : 'Save Changes'; }
    get isDocumentRequired() { return this.selectedLeaveType === 'Training' || this.selectedLeaveType === 'Sick Leave'; }
    get hasRelatedFiles() { return this.relatedFiles && this.relatedFiles.length > 0; }
    
    handleFormLoad(event) {
        if (!this.isNewRecord) {
            const recordFields = event.detail.records[this.recordIdToEdit].fields;
            const leaveType = recordFields.Leave_Type__c.value;
            this.selectedLeaveType = leaveType;
            this.startDate = recordFields.Start_Date__c.value;
            this.endDate = recordFields.End_Date__c.value;
        }
    }

    handleFieldChange(event) {
        const { fieldName, value } = event.target;
        if (fieldName === 'Leave_Type__c') this.selectedLeaveType = value;
        else if (fieldName === 'Start_Date__c') this.startDate = value;
        else if (fieldName === 'End_Date__c') this.endDate = value;
    }
    
    async handleSubmit(event) {
        event.preventDefault(); 
        const fields = { ...event.detail.fields }; 
        try {
            if (fields.Leave_Type__c !== 'Sick Leave' && fields.Leave_Type__c !== 'Training') {
                fields.Leave_Balance__c = await getLeaveBalanceId({ employeeId: userId, leaveType: fields.Leave_Type__c });
            }
            if (this.isNewRecord) {
                fields.Status__c = 'Submitted';
            }
            this.refs.leaveRequestForm.submit(fields);
        } catch (error) {
            this.showToast('Error', 'Could not find leave balance for ' + fields.Leave_Type__c, 'error');
        }
    }

    handleSuccess(event) {
        this.isSaving = false;
        const savedRecordId = event.detail.id;
        if (this.isNewRecord && this.isDocumentRequired) {
            this.recordIdToEdit = savedRecordId;
            this.showUploadStep = true;
        } else {
            this.dispatchEvent(new CustomEvent('success', { detail: { recordId: savedRecordId } }));
        }
    }

    handleError(event) {
        this.isSaving = false;
        const message = event.detail?.detail || event.detail?.message || 'An unknown error occurred.';
        this.showToast('Error saving request', message, 'error');
    }

    handleClose() { this.dispatchEvent(new CustomEvent('close')); }
    
    handleFinish() {
        this.dispatchEvent(new CustomEvent('success', { detail: { recordId: this.recordIdToEdit } }));
    }
    
    triggerSubmit() {
        this.isSaving = true;
        const submitButton = this.template.querySelector('button[type="submit"]');
        if (submitButton) {
            submitButton.click();
        }
    }

    async loadRelatedFiles(recordId) {
        try {
            const files = await getRelatedFiles({ recordId, refresh: Date.now() });
            this.relatedFiles = files.map(f => ({ Id: f.Id, title: f.Title }));
        } catch (error) {
            this.showToast('Error', 'Could not load related files.', 'error');
        }
    }

    async handleRemoveFile(event) {
        const contentDocumentId = event.currentTarget.dataset.id;
        if (!confirm('Are you sure you want to remove this document?')) return;
        try {
            await deleteRelatedFile({ contentDocumentId, recordId: this.recordIdToEdit });
            this.showToast('Success', 'Document removed.', 'success');
            await this.loadRelatedFiles(this.recordIdToEdit);
            this.dispatchEvent(new CustomEvent('filechange', { detail: { recordId: this.recordIdToEdit } }));
        } catch (error) {
            this.showToast('Error', 'Could not remove document.', 'error');
        }
    }

    handleUploadFinished() {
        this.showToast('Success', 'File uploaded successfully.', 'success');
        this.loadRelatedFiles(this.recordIdToEdit);
        this.dispatchEvent(new CustomEvent('filechange', { detail: { recordId: this.recordIdToEdit } }));
    }

    handleFilePreview(event) {
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: { pageName: 'filePreview' },
            state: { selectedRecordId: event.currentTarget.dataset.id }
        });
    }
    
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}