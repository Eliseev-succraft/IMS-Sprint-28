import {LightningElement, api, track} from 'lwc';
import {NavigationMixin} from 'lightning/navigation';
import url from './urlTemplateLink.html';
import navigation from './navigationTemplateLink.html';
import empty from './emptyTemplateLink.html';

/*
*
*    <span style="float: left;">
    <a title={item.Name} target="_blank" onclick={navigateToRecordId} href={recordPageUrl} data-id={item.Id}>{item.Name}</a>
</span>

    navigateToRecordId(event) {
        console.log('%s, time: %f', 'navigateToRecordId', this.timeStamp());
        let id = event.target.dataset.id;
        if (id) {
            // Generate a URL to a User record page
            this[NavigationMixin.GenerateUrl]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: id,
                    actionName: 'view',
                },
            }).then(url => {
                this.recordPageUrl = url;
            });
        } else {
            this.showErrMessage('The event has not been found.');
        }
    }
*
*
* */

export default class lwcUtilityNavigation extends NavigationMixin(LightningElement) {
    @api isDebugLog = false;
    debugLogStyle = 'background: green; color: white;';
    @api template;
    @api label;
    @track url;
    @api target;
    @api rid;

    render() {
        if (this.template) {
            switch (this.template) {
                case 'navigation': {
                    return navigation;
                }
                case 'url': {
                    this.url = '/' + this.rid;
                    return url;
                }
                default:
                    return empty;
            }
        } else {
            return empty;
        }
    }

    navigateToRecord() {
        this.begin('navigateToRecord');
        this.navigateToRecordViewPage(this.rid);
        this.end();
    }

    connectedCallback() {
        this.begin('initialization');
        this.dispatchEvent(new CustomEvent('loaded'));
        this.end();
    }

    @api navigateToSObject(recordId) {
        this.begin('navigateToSObject');
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                actionName: 'view'
            },
        });
        this.end();
    }

    @api navigateToObjectHome(objectApiName) {
        this.begin('navigateToObjectHome');
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: objectApiName,
                actionName: 'home'
            },
        });
        this.end();
    }

    @api navigateToListView(objectApiName, filterName) {
        this.begin('navigateToListView');
        filterName = filterName || 'Recent';
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: objectApiName,
                actionName: 'list'
            },
            state: {
                filterName: filterName
            }
        });
        this.end();
    }

    @api navigateToNewRecordPage(objectApiName) {
        this.begin('navigateToNewRecordPage');
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: objectApiName,
                actionName: 'new'
            }
        });
        this.end();
    }

    @api navigateToRecordViewPage(recordId, objectApiName) {
        this.begin('navigateToRecordViewPage');
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: objectApiName,
                actionName: 'view'
            }
        });
        this.end();
    }

    @api navigateToRecordEditPage(recordId, objectApiName) {
        this.begin('navigateToRecordEditPage');
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: objectApiName,
                actionName: 'edit'
            }
        });
        this.end();
    }

    @api navigateToRelatedList(recordId, objectApiName, relationshipApiName) {
        this.begin('navigateToRelatedList');
        this[NavigationMixin.Navigate]({
            type: 'standard__recordRelationshipPage',
            attributes: {
                recordId: recordId,
                objectApiName: objectApiName,
                relationshipApiName: relationshipApiName,
                actionName: 'view'
            }
        });
        this.end();
    }

    @api navigateToTabPage(tabName) {
        this.begin('navigateToTabPage');
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: tabName
            }
        });
        this.end();
    }

    @api navigateToWebPage(url) {
        this.begin('navigateToWebPage');
        this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: url
                }
            },
            true
        );
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