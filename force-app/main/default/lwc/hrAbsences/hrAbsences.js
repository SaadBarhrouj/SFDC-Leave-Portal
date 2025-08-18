import { LightningElement, track, wire } from 'lwc';
import getAbsentEmployees from '@salesforce/apex/LeaveRequestController.getAbsentEmployees';
import { refreshApex } from '@salesforce/apex';

const COLUMNS = [
    {
        label: 'Employee',
        fieldName: 'employeeUrl',
        type: 'avatarType',
        typeAttributes: {
            name: { fieldName: 'employeeName' },
            url: { fieldName: 'employeeUrl' },
            initials: { fieldName: 'employeeInitials' }
        }
    },
    { label: 'Leave Type', fieldName: 'leaveType', type: 'text' },
    { label: 'Start Date', fieldName: 'startDate', type: 'date-local' },
    { label: 'End Date', fieldName: 'endDate', type: 'date-local' }
];

const DEFAULT_FILTERS = {
    employeeName: '',
    leaveType: '',
    startDate: null,
    endDate: null
};

export default class HrAbsences extends LightningElement {
    @track columns = COLUMNS;
    @track originalAbsences = [];
    @track absences = [];

    @track filterValues = { ...DEFAULT_FILTERS };
    @track showFilterPopover = false;
    isLoading = true;
    wiredAbsencesResult;

    leaveTypeOptions = [
        { label: 'All Types', value: '' },
        { label: 'Paid Leave', value: 'Paid Leave' },
        { label: 'Unpaid Leave', value: 'Unpaid Leave' },
        { label: 'RTT', value: 'RTT' },
        { label: 'Sick Leave', value: 'Sick Leave' },
        { label: 'Training', value: 'Training' }
    ];

    @wire(getAbsentEmployees)
    wiredAbsences(result) {
        this.isLoading = true;
        this.wiredAbsencesResult = result;
        if (result.data) {
            this.originalAbsences = result.data.map(item => {
                const employeeName = item.Requester__r ? item.Requester__r.Name : 'Unknown User';
                let employeeInitials = 'UU';
                if (employeeName && employeeName !== 'Unknown User') {
                    const nameParts = employeeName.trim().split(' ').filter(part => part);
                    if (nameParts.length > 1) {
                        employeeInitials = (nameParts[0].charAt(0) + nameParts[nameParts.length - 1].charAt(0)).toUpperCase();
                    } else if (nameParts.length === 1 && nameParts[0].length > 0) {
                        employeeInitials = employeeName.substring(0, 2).toUpperCase();
                    }
                }
                
                return {
                    id: item.Id,
                    employeeName: employeeName,
                    employeeUrl: item.Requester__r ? `/lightning/r/User/${item.Requester__c}/view` : '',
                    employeePhotoUrl: item.Requester__r ? item.Requester__r.FullPhotoUrl : '',
                    employeeInitials: employeeInitials,
                    leaveType: item.Leave_Type__c,
                    startDate: item.Start_Date__c,
                    endDate: item.End_Date__c
                };
            });
            this.applyFilters();
        } else if (result.error) {
            console.error('Error fetching absent employees:', result.error);
            this.originalAbsences = [];
            this.absences = [];
        }
        this.isLoading = false;
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
        this.showFilterPopover = false;
    }

    applyFilters() {
        let data = [...this.originalAbsences];
        const { employeeName, leaveType, startDate, endDate } = this.filterValues;

        if (employeeName) {
            const lowerCaseName = employeeName.toLowerCase();
            data = data.filter(item => item.employeeName && item.employeeName.toLowerCase().includes(lowerCaseName));
        }
        if (leaveType) {
            data = data.filter(item => item.leaveType === leaveType);
        }
        
        this.absences = data;
        this.showFilterPopover = false;
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredAbsencesResult).finally(() => {
            this.isLoading = false;
        });
    }

    get filterButtonVariant() {
        return this.showFilterPopover ? 'brand' : 'neutral';
    }

    get hasAbsences() {
        return this.absences && this.absences.length > 0;
    }


    handleExportPDF() {
        const params = [];
        if (this.filterValues.employeeName) {
            params.push('employeeName=' + encodeURIComponent(this.filterValues.employeeName));
        }
        if (this.filterValues.leaveType) {
            params.push('leaveType=' + encodeURIComponent(this.filterValues.leaveType));
        }

        const url = '/apex/HrAbsencesExport' + (params.length ? '?' + params.join('&') : '');
        window.open(url, '_blank');
    }
}
