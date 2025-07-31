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

    @wire(getLeavePolicySettings)
    wiredSettings(result) {
        this.isLoading = true;
        this.wiredSettingsResult = result;
        if (result.data) {
            this.settings = { ...result.data };
            this.originalSettings = { ...result.data };
            this.isLoading = false;
        } else if (result.error) {
            this.showToast('Error Loading Settings', 'An error occurred while loading settings.', 'error');
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
    }

    handleInputChange(event) {
        this.settings.Annual_Paid_Leave_Days__c = event.target.value;
    }

    handleSave() {
        this.isLoading = true;
        
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
                this.showToast('Error Saving', error.body.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}