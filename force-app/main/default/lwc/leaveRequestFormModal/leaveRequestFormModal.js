import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import userId from '@salesforce/user/Id';

import getNumberOfDaysRequested from '@salesforce/apex/LeaveRequestController.getNumberOfDaysRequested';
import getRelatedFiles from '@salesforce/apex/LeaveRequestDetailController.getRelatedFiles';
import deleteRelatedFile from '@salesforce/apex/LeaveRequestDetailController.deleteRelatedFile';
import recallAndUpdate from '@salesforce/apex/LeaveRequestController.recallAndUpdate';

export default class LeaveRequestFormModal extends NavigationMixin(LightningElement) {
    _recordId;

    @track selectedLeaveType = '';
    @track startDate;
    @track endDate;
    @track numberOfDaysRequested = 0;
    @track showUploadStep = false;
    @track relatedFiles = [];
    @track isSaving = false;
    @track hasChanges = false;
    
    originalValues = {};
    originalStatus = '';

    acceptedFormats = ['.pdf', '.png', '.jpg', '.jpeg'];

    @api
    set recordIdToEdit(value) {
        this._recordId = value;
        if (value) {
            this.loadRelatedFiles(value);
        } else {
            this.relatedFiles = [];
            this.selectedLeaveType = '';
            this.hasChanges = false;
        }
    }
    get recordIdToEdit() {
        return this._recordId;
    }

    get isSubmitButtonDisabled() {
        return this.isSaving || !this.hasChanges;
    }

    get isLeaveTypeDisabled() {
        return !this.isNewRecord;
    }
    
    get isStartDateDisabled() {
        return !this.isNewRecord && this.selectedLeaveType === 'Sick Leave';
    }
    get isEndDateDisabled() {
        return !this.isNewRecord && this.selectedLeaveType === 'Sick Leave';
    }
    @wire(getNumberOfDaysRequested, { startDate: '$startDate', endDate: '$endDate' })
    wiredDays({ error, data }) {
        if (data || data === 0) this.numberOfDaysRequested = data;
        else if (error) this.numberOfDaysRequested = 0;
    }

    get currentUserId() { return userId; }
    get isNewRecord() { return !this.recordIdToEdit; }
    
    get modalTitle() {
        if (!this.isNewRecord && this.selectedLeaveType === 'Sick Leave') {
        return 'Upload Medical Certificate';
    }
        if (this.showUploadStep) return 'Upload Supporting Document';
        return this.isNewRecord ? 'New Leave Request' : 'Edit Leave Request';
    }

    get submitButtonLabel() {
        if (this.isSaving) { return 'Saving...'; }
        return this.isNewRecord ? 'Submit Request' : 'Save Changes';
    }

    get isDocumentRequired() { return this.selectedLeaveType === 'Training' || this.selectedLeaveType === 'Sick Leave'; }
    get hasRelatedFiles() { return this.relatedFiles && this.relatedFiles.length > 0; }

    handleFormLoad(event) {
        if (!this.isNewRecord) {
            const fields = event.detail.records[this.recordIdToEdit].fields;
            this.originalStatus = fields.Status__c.value;

            this.originalValues = {
                Leave_Type__c: fields.Leave_Type__c.value,
                Start_Date__c: fields.Start_Date__c.value,
                End_Date__c: fields.End_Date__c.value,
                Employee_Comments__c: fields.Employee_Comments__c.value || ''
            };

            this.selectedLeaveType = fields.Leave_Type__c.value;
            this.startDate = fields.Start_Date__c.value;
            this.endDate = fields.End_Date__c.value;
            this.hasChanges = false;
        }
    }

    handleFieldChange(event) {
        const { fieldName, value } = event.target;
        if (fieldName === 'Leave_Type__c') this.selectedLeaveType = value;
        else if (fieldName === 'Start_Date__c') this.startDate = value;
        else if (fieldName === 'End_Date__c') this.endDate = value;

        if (this.isNewRecord) {
            this.hasChanges = true;
            return;
        }

        const currentValues = this.getValuesFromForm();
        this.hasChanges = (
            currentValues.Leave_Type__c !== this.originalValues.Leave_Type__c ||
            currentValues.Start_Date__c !== this.originalValues.Start_Date__c ||
            currentValues.End_Date__c !== this.originalValues.End_Date__c ||
            (currentValues.Employee_Comments__c || '') !== this.originalValues.Employee_Comments__c
        );
    }
    
    async handleSubmit(event) {
        event.preventDefault(); 
        this.isSaving = true;

        const fields = { ...event.detail.fields }; 
        const specialHandlingStatuses = ['Pending Manager Approval', 'Pending HR Approval', 'Escalated to Senior Manager'];

        if (!this.isNewRecord && specialHandlingStatuses.includes(this.originalStatus)) {
            try {
                await recallAndUpdate({
                    recordId: this.recordIdToEdit,
                    startDate: fields.Start_Date__c,
                    endDate: fields.End_Date__c,
                    comments: fields.Employee_Comments__c
                });
                this.dispatchEvent(new CustomEvent('success', { detail: { recordId: this.recordIdToEdit } }));
            } catch (error) {
                this.showToast('Error', error.body?.message || 'An error occurred.', 'error');
            } finally {
                this.isSaving = false;
            }
        } else {
            this.refs.leaveRequestForm.submit(fields);
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

    triggerSubmit() {
        this.template.querySelector('button[type="submit"]').click();
    }
    
    getValuesFromForm() {
        const fields = this.template.querySelectorAll('lightning-input-field');
        const values = {};
        fields.forEach(field => {
            if (field.fieldName) {
                values[field.fieldName] = field.value;
            }
        });
        return values;
    }

    handleClose() { this.dispatchEvent(new CustomEvent('close')); }
    
    handleFinish() {
        this.dispatchEvent(new CustomEvent('success', { detail: { recordId: this.recordIdToEdit } }));
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
            this.hasChanges = true;
            this.dispatchEvent(new CustomEvent('filechange', { detail: { recordId: this.recordIdToEdit } }));
        } catch (error) {
            this.showToast('Error', 'Could not remove document.', 'error');
        }
    }

    handleUploadFinished() {
        this.showToast('Success', 'File uploaded successfully.', 'success');
        this.loadRelatedFiles(this.recordIdToEdit);
        this.hasChanges = true;
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