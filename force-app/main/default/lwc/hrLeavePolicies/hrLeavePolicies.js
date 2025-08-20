import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import getLeavePolicySettings from '@salesforce/apex/LeavePolicySettingsController.getLeavePolicySettings';
import saveLeavePolicySettings from '@salesforce/apex/LeavePolicySettingsController.saveLeavePolicySettings';

export default class HrLeavePolicies extends LightningElement {
    @track settings = {};
    originalSettings = {};
    isLoading = false;
    isEditMode = false;
    wiredSettingsResult;
    errorMessage = '';

    @wire(getLeavePolicySettings)
    wiredSettings(result) {
        this.isLoading = true;
        this.wiredSettingsResult = result;
        if (result.data) {
            this.settings = { ...result.data };
            this.originalSettings = { ...result.data };
            this.isLoading = false;
        } else if (result.error) {
            this.showToast('Error Loading', 'An error occurred while loading the settings.', 'error');
            this.errorMessage = 'Failed to load settings: ' + result.error.body.message;
            this.isLoading = false;
        }
    }

    get isReadOnly() {
        return !this.isEditMode;
    }

    handleEdit() {
        this.isEditMode = true;
    }

    handleCancel() {
        this.settings = { ...this.originalSettings };
        this.isEditMode = false;
        this.clearError();
    }

    handleInputChange(event) {
        const field = event.target.name;
        const value = event.target.value;
        this.settings = { ...this.settings, [field]: value };
    }

    clearError() {
        this.errorMessage = '';
    }

    handleSave() {
        this.clearError();
        this.isLoading = true;
        
        if (this.settings.Annual_Paid_Leave_Days__c === undefined || this.settings.Annual_Paid_Leave_Days__c === null || this.settings.Annual_Paid_Leave_Days__c === '') {
            this.errorMessage = 'Annual Paid Leave Days cannot be empty.';
            this.isLoading = false;
            return;
        }
        
        if (this.settings.Minimum_Notice_Period_Days__c === undefined || this.settings.Minimum_Notice_Period_Days__c === null || this.settings.Minimum_Notice_Period_Days__c === '') {
            this.errorMessage = 'Minimum Notice Period Days cannot be empty.';
            this.isLoading = false;
            return;
        }

        if (this.settings.Annual_RTT_Days__c === undefined || this.settings.Annual_RTT_Days__c === null || this.settings.Annual_RTT_Days__c === '') {
            this.errorMessage = 'Annual RTT Days cannot be empty.';
            this.isLoading = false;
            return;
        }

        const settingsToSave = {
            ...this.settings,
            sobjectType: 'Leave_Policy_Settings__c'
        };

        saveLeavePolicySettings({ settingsToSave: settingsToSave })
            .then(() => {
                this.showToast('Success', 'Policy settings have been saved.', 'success');
                this.isEditMode = false;
                return refreshApex(this.wiredSettingsResult);
            })
            .catch(error => {
                const errorMessage = error.body.message || 'An unknown error occurred.';
                this.showToast('Error Saving', errorMessage, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}