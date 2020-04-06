import {LightningElement, api} from 'lwc';

export default class lwcUtilityModal extends LightningElement {
    @api isDebugLog = false;
    @api modals = {};
    debugLogStyle = 'background: green; color: white;';

    connectedCallback() {
        this.begin('initialization');
        this.dispatchEvent(new CustomEvent('loaded'));
        this.end();
    }

    @api showModal(attribute) {
        this.begin('showModal');
        this.log('attribute', attribute);
        this.modals[attribute] = true;
        this.dispatchEvent(new CustomEvent('updatemodals', {detail: {modals: JSON.stringify(this.modals)}}));
        this.end();
    }

    @api closeModal(attribute) {
        this.begin('closeModal');
        this.log('attribute', attribute);
        this.modals[attribute] = false;
        this.dispatchEvent(new CustomEvent('updatemodals', {detail: {modals: JSON.stringify(this.modals)}}));
        this.end();
    }

    begin(name) {
        if (this.isDebugLog) {
            console.group('%s, time: %f', name, this.timeStamp());
        }
    }

    end() {
        if (this.isDebugLog) {
            console.groupEnd();
        }
    }

    log(label, values, style) {
        if (this.isDebugLog) {
            style = style || this.debugLogStyle;
            if (values === undefined) {
                values = label;
                label = null;
            }
            if (Array.isArray(values)) {
                if (label !== null) {
                    console.log('%c' + label, style);
                }
                console.log(JSON.parse(JSON.stringify(values)));
            } else if (typeof values === 'object') {
                if (label !== null) {
                    console.log('%c' + label, style);
                }
                console.log(JSON.parse(JSON.stringify(values)));
            } else {
                if (label !== null) {
                    console.log('%c' + label + ' - ' + values, style);
                } else {
                    console.log('%c' + values, style);
                }
            }
        }
    }

    timeStamp() {
        return performance.now() / 1000;
    }
}