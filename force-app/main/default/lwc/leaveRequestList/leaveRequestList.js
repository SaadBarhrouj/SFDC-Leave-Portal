import { LightningElement, api } from 'lwc';

export default class LeaveRequestList extends LightningElement {
    @api requests = [];
    @api columns = [];

    get hasRequests() {
        return this.requests && this.requests.length > 0;
    }

    @api
    clearSelection() {
        if (this.refs.datatable) {
            this.refs.datatable.selectedRows = [];
        }
    }

    @api
    setSelectedRows(ids) {
        if (this.refs.datatable) {
            this.refs.datatable.selectedRows = ids;
        }
    }

    handleRowAction(event) {
        this.dispatchEvent(new CustomEvent('rowaction', { detail: event.detail }));
    }

    handleRowSelection(event) {
        this.dispatchEvent(new CustomEvent('rowselection', { detail: event.detail }));
    }
}