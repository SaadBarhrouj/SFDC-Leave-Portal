import LightningDatatable from 'lightning/datatable';
import statusBadgeTemplate from './statusBadgeTemplate.html';

export default class RequestsDatatable extends LightningDatatable {
    static customTypes = {
        customBadge: {
            template: statusBadgeTemplate,
            typeAttributes: ['value', 'class'],
            standardCellLayout: true
        }
    };
}