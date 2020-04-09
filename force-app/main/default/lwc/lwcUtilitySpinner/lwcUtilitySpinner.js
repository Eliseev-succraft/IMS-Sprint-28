import {LightningElement, api, track} from 'lwc';

export default class lwcUtilitySpinner extends LightningElement {
    @api alternativeText = 'Loading';
    @api size = 'medium';
    @api variant = 'brand';
    @api delay = 60000;
    @api isDebugLog = false;
    runs = [];
    queue = [];
    @track isLoading = false;
    debugLogStyle = 'background: green; color: white;';


    connectedCallback() {
        this.begin('initialization');
        this.dispatchEvent(new CustomEvent('loaded'));
        this.end();
    }

    @api showSpinner(timeStamp, delay) {
        this.begin('showSpinner');
        let that = this;
        timeStamp = timeStamp || new Date().getTime();
        delay = delay || that.delay;
        that.log('timeStamp: ' + timeStamp);
        if (that.queue.indexOf(timeStamp) === -1) {
            that.queue.push(timeStamp);
            that.isLoading = true;
            if (that.runs.length === 0) {
                that.dispatchEvent(new CustomEvent('started'));
                that.runs.push(timeStamp);
                setTimeout(() => {
                    that.log('getCallback hideSpinner');
                    if (that.runs.indexOf(timeStamp) !== -1) {
                        that.queue = [];
                        that.runs = [];
                        that.isLoading = false;
                        that.dispatchEvent(new CustomEvent('stopped'));
                    }
                }, delay);
            }
        }
        this.end();
        return timeStamp;
    }

    @api hideSpinner(timeStamp) {
        this.begin('hideSpinner');
        let that = this;
        that.log('timeStamp: ' + timeStamp);
        let index = that.queue.indexOf(timeStamp);
        if (index !== -1) {
            if (that.queue.length === 1) {
                that.runs = [];
                that.queue = [];
                that.isLoading = false;
                that.dispatchEvent(new CustomEvent('stopped'));
            } else {
                that.queue.splice(index, 1);
            }
        }
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