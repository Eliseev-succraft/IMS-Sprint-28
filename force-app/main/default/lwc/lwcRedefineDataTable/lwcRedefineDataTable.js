import LightningDatatable from 'lightning/datatable';
import navigationType from './navigationType.html';

export default class lwcRedefineDataTable extends LightningDatatable {
    static delegatesFocus = false;
    static customTypes = {
        navigation: {
            template: navigationType,
            typeAttributes: ['label','recordId', 'target', 'template'],
        }
    };
}