import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import getAllHolidays from '@salesforce/apex/HolidayController.getAllHolidays';
import deleteHoliday from '@salesforce/apex/HolidayController.deleteHoliday';

import HOLIDAY_OBJECT from '@salesforce/schema/Holiday__c';
import HOLIDAY_NAME_FIELD from '@salesforce/schema/Holiday__c.Name';
import HOLIDAY_DATE_FIELD from '@salesforce/schema/Holiday__c.Holiday_Date__c';
import HOLIDAY_COUNTRY_CODE_FIELD from '@salesforce/schema/Holiday__c.Country_Code__c';
import HOLIDAY_DEDUCTION_FIELD from '@salesforce/schema/Holiday__c.Deduction_Value__c';
import HOLIDAY_DESCRIPTION_FIELD from '@salesforce/schema/Holiday__c.Description__c';

const ACTIONS = [{ label: 'Edit', name: 'edit' }, { label: 'Delete', name: 'delete' }];
const COLUMNS = [
    { label: 'Holiday Name', fieldName: 'Name', type: 'text' },
    { label: 'Date', fieldName: 'Holiday_Date__c', type: 'date-local' },
    { label: 'Country Code', fieldName: 'Country_Code__c', type: 'text' },
    { label: 'Deduction Value', fieldName: 'Deduction_Value__c', type: 'number', cellAttributes: { alignment: 'left' } },
    { label: 'Description', fieldName: 'Description__c', type: 'text' },
    { type: 'action', typeAttributes: { rowActions: ACTIONS } }
];

const STATIC_COUNTRIES = [
    { label: 'France', value: 'FR' },
    { label: 'United States', value: 'US' },
    { label: 'Morocco', value: 'MA' },
];

export default class HrHolidays extends LightningElement {
    @track columns = COLUMNS;
    @track allHolidays = [];
    @track filteredHolidays = [];
    wiredHolidaysResult;

    holidayObjectApiName = HOLIDAY_OBJECT;
    holidayNameField = HOLIDAY_NAME_FIELD;
    holidayDateField = HOLIDAY_DATE_FIELD;
    holidayCountryCodeField = HOLIDAY_COUNTRY_CODE_FIELD;
    holidayDeductionField = HOLIDAY_DEDUCTION_FIELD;
    holidayDescriptionField = HOLIDAY_DESCRIPTION_FIELD;
    
    countryOptions = [{ label: 'All Countries', value: '' }, ...STATIC_COUNTRIES];
    syncCountryOptions = STATIC_COUNTRIES;

    @track filterValues = {};
    @track activeFilters = {};

    isLoading = true;
    isModalOpen = false;
    isSyncModalOpen = false;
    showFilterPopover = false;
    modalTitle = '';
    countryToSync = '';
    recordIdToEdit = null;

    @wire(getAllHolidays)
    wiredHolidays(result) {
        this.wiredHolidaysResult = result;
        if (result.data) {
            this.allHolidays = result.data;
            this.applyFilters();
        } else if (result.error) {
            this.showToast('Error', 'Could not load holiday data.', 'error');
        }
        this.isLoading = false;
    }

    connectedCallback() {
        this.clearFilters();
    }

    get hasHolidays() {
        return this.filteredHolidays && this.filteredHolidays.length > 0;
    }

    get filterButtonVariant() {
        return this.showFilterPopover ? 'brand' : 'neutral';
    }

    get isSyncDisabled() {
        return !this.countryToSync;
    }
    
    toggleFilterPopover() {
        if (!this.showFilterPopover) {
            this.filterValues = { ...this.activeFilters };
        }
        this.showFilterPopover = !this.showFilterPopover;
    }

    handleFilterValueChange(event) {
        const { name, value } = event.target;
        this.filterValues = { ...this.filterValues, [name]: value };
    }

    clearFilters() {
        const defaultFilters = { country: '', year: new Date().getFullYear() };
        this.filterValues = defaultFilters;
        this.activeFilters = defaultFilters;
        
        if (this.allHolidays && this.allHolidays.length > 0) {
            this.applyFilters();
        }

        if (this.showFilterPopover) {
            this.showFilterPopover = false;
        }
    }

    applyFilters() {
        this.activeFilters = { ...this.filterValues };
        let holidays = this.allHolidays;

        if (this.activeFilters.country) {
            holidays = holidays.filter(h => h.Country_Code__c === this.activeFilters.country);
        }
        if (this.activeFilters.year) {
            holidays = holidays.filter(h => new Date(h.Holiday_Date__c).getFullYear() === parseInt(this.activeFilters.year, 10));
        }
        
        this.filteredHolidays = holidays;
        this.showFilterPopover = false;
    }

    openSyncModal() {
        this.isSyncModalOpen = true;
    }

    closeSyncModal() {
        this.isSyncModalOpen = false;
        this.countryToSync = '';
    }

    handleSyncCountryChange(event) {
        this.countryToSync = event.detail.value;
    }

    handleSync() {
        this.showToast('Info', 'Sync action is not implemented yet.', 'info');
        this.closeSyncModal();
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredHolidaysResult).finally(() => {
            this.isLoading = false;
        });
    }
    
    handleRowAction(event) {
        const { action, row } = event.detail;
        if (action.name === 'edit') {
            this.modalTitle = 'Edit Holiday';
            this.recordIdToEdit = row.Id;
            this.isModalOpen = true;
        } else if (action.name === 'delete') {
            this.handleDelete(row);
        }
    }

    handleDelete(row) {
        if (confirm(`Are you sure you want to delete "${row.Name}"?`)) {
            this.isLoading = true;
            deleteHoliday({ holidayId: row.Id })
                .then(() => {
                    this.showToast('Success', 'Holiday deleted successfully.', 'success');
                    return this.handleRefresh();
                })
                .catch(error => {
                    this.showToast('Error', error.body.message, 'error');
                })
                .finally(() => {
                    this.isLoading = false;
                });
        }
    }

    handleNew() {
        this.modalTitle = 'Add Holiday';
        this.recordIdToEdit = null;
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
    }

    handleSuccess(event) {
        const toastMessage = this.recordIdToEdit ? 'Holiday updated successfully.' : 'Holiday created successfully.';
        this.showToast('Success', toastMessage, 'success');
        this.closeModal();
        this.handleRefresh();
    }
    
    handleError(event){
        this.showToast('Error saving record', event.detail.message, 'error');
    }
    
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}