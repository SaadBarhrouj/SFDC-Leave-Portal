import LightningDatatable from 'lightning/datatable';
import statusBadgeTemplate from './statusBadgeTemplate.html';
import avatarTypeTemplate from './avatarTypeTemplate.html';
export default class RequestsDatatable extends LightningDatatable {
    static customTypes = {
        customBadge: {
            template: statusBadgeTemplate,
            typeAttributes: ['value', 'class'],
            standardCellLayout: true
        },
         avatarType: {
            template: avatarTypeTemplate,
            standardCellLayout: false,
            typeAttributes: ['name', 'url', 'initials']
        }
    };
        
}