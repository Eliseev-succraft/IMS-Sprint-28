import {LightningElement, api, track} from 'lwc';

export default class lwcPaginationBar extends LightningElement {
    @api results; // all results
    @api count; // number of results per page
    @api isDebugLog;
    @api maxPageButtons;
    @track pagination = {
        visible: true,
        pages: 0, // all available pages from results
        currentPage: 0,
        results: [],
        totalResults: 0,
        startResult: 0,
        stopResults: 0,
        buttonsBar: {
            visible: false,
            controlButtons: {
                previous: {
                    visible: true,
                    disabled: false,
                    label: 'Previous',
                    iconName: 'utility:left',
                    iconPosition: 'left',
                    variant: ''
                },
                next: {
                    visible: true,
                    disabled: false,
                    label: 'Next',
                    iconName: 'utility:right',
                    iconPosition: 'right',
                    variant: ''
                }
            },
            buttons: [
                {
                    id: '',
                    label: '',
                    visible: false,
                    variant: ''
                }
            ]
        }
    };
    logSettings = {
        text: '',
        array: 'background: green; color: white;',
        object: 'background: green; color: white;',
    };

    connectedCallback() {
        this.startMethod('connectedCallback');
        this.log('initialization');
        this.maxPageButtons = Number(this.maxPageButtons);
        this.count = Number(this.count);
        this.stopMethod();
    }

    @api
    generatePages() {
        this.startMethod('generatePages');
        this.log('results', this.results);
        this.pagination.results = [];
        if (this.results) {
            if (Array.isArray(this.results)) {
                let size = this.results.length;
                if (size) {
                    this.pagination.currentPage = 1;
                    this.pagination.totalResults = size;
                    this.pagination.pages = Math.ceil(size / this.count);
                    // generation additional buttons
                    let buttons = [];
                    if (this.pagination.pages === 1) {
                        this.pagination.buttonsBar.visible = false;
                    } else {
                        for (let i = 0; i < this.pagination.pages; i++) {
                            buttons.push({
                                id: i,
                                label: (i + 1).toString(),
                                visible: false,
                                disabled: false,
                                variant: ''
                            });
                        }
                        buttons.push({
                            id: this.pagination.pages + 1,
                            label: '...',
                            visible: false,
                            disabled: false,
                            variant: ''
                        });
                        this.pagination.buttonsBar.visible = true;
                    }
                    this.pagination.buttonsBar.buttons = buttons;
                    this.log('pagination', this.pagination);
                    this.setVisibleButtonNext();
                    // END generation additional buttons
                    for (let p = 0; p < this.pagination.pages; p++) {
                        let pageRecords = [];
                        let startIndex = p * this.count;
                        let n = 0;
                        while (n < this.count) {
                            if (!this.results[startIndex + n]) {
                                break;
                            }
                            pageRecords.push(this.results[startIndex + n]);
                            n++;
                        }
                        this.pagination.results.push(pageRecords);
                    }
                    this.showResultsPage();
                } else {
                    this.pagination.currentPage = 1;
                    this.pagination.totalResults = 0;
                    this.pagination.pages = 1;
                    this.pagination.buttonsBar.visible = false;
                    this.pagination.buttonsBar.buttons = [];
                    this.results = [];
                    this.showResultsPage();
                }
            }
        }
        this.log('pagination', this.pagination);
        this.stopMethod();
    }

    showResultsPage() {
        this.startMethod('showResultsPage');
        this.pagination.startResult = (this.pagination.currentPage - 1) * this.count + 1;
        this.pagination.stopResult = this.pagination.startResult + this.count - 1;
        // delete active btn background
        let size = this.pagination.buttonsBar.buttons.length - 1;
        for (let i = 0; i < size; i++) {
            this.pagination.buttonsBar.buttons[i].variant = '';
        }
        // END delete active btn background
        if (size > 0) {
            this.pagination.buttonsBar.buttons[this.pagination.currentPage - 1].variant = 'brand';
        }
        // disabled control buttons
        if (this.pagination.currentPage === 1) {
            this.pagination.buttonsBar.controlButtons.previous.disabled = true;
            this.pagination.buttonsBar.controlButtons.next.disabled = false;
        } else if (this.pagination.currentPage === this.pagination.pages) {
            this.pagination.buttonsBar.controlButtons.previous.disabled = false;
            this.pagination.buttonsBar.controlButtons.next.disabled = true;
        } else {
            this.pagination.buttonsBar.controlButtons.previous.disabled = false;
            this.pagination.buttonsBar.controlButtons.next.disabled = false;
        }
        // END disabled control buttons
        const selectedEvent = new CustomEvent('show', {detail: this.pagination.results[this.pagination.currentPage - 1]});
        this.dispatchEvent(selectedEvent);
        this.stopMethod();
    }

    setVisibleButtonNext() {
        this.startMethod('setVisibleButtonNext');
        if (this.pagination.buttonsBar.buttons.length > 0 && !this.pagination.buttonsBar.buttons[this.pagination.currentPage - 1].visible) {
            let size = this.pagination.buttonsBar.buttons.length - 1;
            let cnt = 0;
            let cntVsb = 0;
            let start = false;
            let flag = false;
            for (let i = 0; i < size; i++) {
                if (i === this.pagination.currentPage - 1) {
                    start = true;
                }
                if (start) {
                    if (cnt < this.maxPageButtons) {
                        this.pagination.buttonsBar.buttons[i].visible = true;
                        cntVsb = i;
                        flag = true;
                    }
                    cnt++;
                } else {
                    this.pagination.buttonsBar.buttons[i].visible = false;
                }
            }
            if (flag) {
                this.pagination.buttonsBar.buttons[this.pagination.pages].visible = (this.pagination.pages - cntVsb > 1);
                // this.pagination.buttonsBar.buttons[this.pagination.pages].visible = (this.pagination.pages - this.maxPageButtons >= 1);
            }
        }
        this.stopMethod();
    }

    setVisibleButtonPrevious() {
        this.startMethod('setVisibleButtonPrevious');
        if (this.pagination.buttonsBar.buttons.length > 0 && !this.pagination.buttonsBar.buttons[this.pagination.currentPage - 1].visible) {
            let size = this.pagination.buttonsBar.buttons.length - 1;
            let cnt = 0;
            let cntVsb = 0;
            let start = false;
            let flag = false;
            for (let i = size; i >= 0; i--) {
                if (i === this.pagination.currentPage - 1) {
                    start = true;
                }
                if (start) {
                    if (cnt < this.maxPageButtons) {
                        this.pagination.buttonsBar.buttons[i].visible = true;
                        flag = true;
                        cntVsb = i;
                    }
                    cnt++;
                } else {
                    this.pagination.buttonsBar.buttons[i].visible = false;
                }
            }
            if (flag) {
                this.pagination.buttonsBar.buttons[this.pagination.pages].visible = (this.pagination.pages - cntVsb > 1);
                // this.pagination.buttonsBar.buttons[this.pagination.pages].visible = (this.pagination.pages - this.maxPageButtons >= 1);
            }
        }
        this.stopMethod();
    }

    paginationPrevious() {
        this.startMethod('paginationPrevious');
        if (this.pagination.currentPage > 1) {
            this.pagination.currentPage--;
            this.showResultsPage();
            this.setVisibleButtonPrevious();
        }
        this.stopMethod();
    }

    paginationNext() {
        this.startMethod('paginationNext');
        if (this.pagination.currentPage < this.pagination.pages) {
            this.pagination.currentPage++;
            this.showResultsPage();
            this.setVisibleButtonNext();
        }
        this.stopMethod();
    }

    handleClickBtnPage(event) {
        this.startMethod('handleClickBtnPage');
        let page = event.target.dataset.id;
        this.log('page', page);
        if (page) {
            if (page > this.pagination.pages) {
                let size = this.pagination.buttonsBar.buttons.length - 2;
                for (let i = size; i >= 0; i--) {
                    if (this.pagination.buttonsBar.buttons[i].visible) {
                        this.pagination.currentPage = i + 2;
                        break;
                    }
                }
                this.showResultsPage();
                this.setVisibleButtonNext();
            } else {
                this.pagination.currentPage = Number(page) + 1;
                this.showResultsPage();
            }
        } else {
            this.showErrMessage('The event was not found.');
        }
        this.stopMethod();
    }

    startMethod(name) {
        if (this.isDebugLog) {
            console.group('%s, time: %f', name, this.timeStamp());
        }
    }

    stopMethod() {
        if (this.isDebugLog) {
            console.groupEnd();
        }
    }

    log(label, values, style) {
        if (this.isDebugLog) {
            style = style || '';
            if (!values) {
                values = label;
                label = '';
            }
            if (Array.isArray(values)) {
                if (!style) {
                    style = this.logSettings.array;
                }
                if (label) {
                    console.log('%c' + label, style);
                }
                console.log(JSON.parse(JSON.stringify(values)));
            } else if (typeof values === 'object') {
                style = this.logSettings.object;
                if (label) {
                    console.log('%c' + label, style);
                }
                console.log(JSON.parse(JSON.stringify(values)));
            } else {
                if (!style) {
                    style = this.logSettings.text;
                }
                if (label) {
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

    showErrMessage(message, title) {
        this.log('showErrMessage');
        this.showMessage(title, message, 'error');
    }

    showSuccessMessage(message, title) {
        this.log('showSuccessMessage');
        this.showMessage(title, message, 'success');
    }

    showWarningMessage(message, title) {
        this.log('showWarningMessage');
        this.showMessage(title, message, 'warning');
    }

    showMessage(title, message, type, mode) {
        this.log('showMessage');
        mode = mode || 'dismissable';
        // pester—Remains visible for 3 seconds.
        // sticky—Remains visible until the user clicks the close button.
        switch (type) {
            case 'error':
                console.error(message);
                break;
            case 'warning':
                console.warn(message);
                break;
            default:
                console.log(type + ' ' + message);
        }
        const toast = new ShowToastEvent({
            'title': title,
            'message': message,
            'messageData': [
                'Salesforce',
                {
                    url: 'http://www.salesforce.com/',
                    label: 'here'
                }
            ],
            'variant': type,
            'mode': mode
        });
        if (toast !== undefined) {
            this.dispatchEvent(toast);
        }
        else {
            alert(message);
        }
    }
}