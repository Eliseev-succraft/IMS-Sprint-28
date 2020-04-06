({
    doInit: function (cmp, event, helper) {
        console.group('%s, time: %f', 'doInit', helper.timeStamp());
        console.log(JSON.stringify(cmp.get('v.spinners')));
        // delete helper['spinners'];
        helper.showSpinner(cmp, 'v.isLoading', 5000, 'doInit');
        helper.getFieldSets(cmp);
        console.groupEnd();
    },

    formLoad: function (cmp, event, helper) {
        console.group('%s, time: %f', 'formLoad', helper.timeStamp());
        let payload = event.getParams();
        if (payload) {
            if (payload.hasOwnProperty('recordUi')) {
                if (payload['recordUi'].hasOwnProperty('record')) {
                    if (payload['recordUi']['record'].hasOwnProperty('fields')) {
                        cmp.set('v.simpleRecord', payload['recordUi']['record']['fields']);
                        console.log(JSON.parse(JSON.stringify(cmp.get('v.simpleRecord'))));
                    }
                }
            }
        }
        helper.hideSpinner(cmp, 'v.isLoading', 'doInit');
        console.groupEnd();
    },

    handleSectionClick: function (cmp, event, helper) {
        console.log('%s, time: %f', 'handleSectionClick', helper.timeStamp());
        if (event.currentTarget.id) {
            cmp.set('v.sections.' + event.currentTarget.id, !cmp.get('v.sections')[event.currentTarget.id]);
        }
    },

    handleTopFieldSetSectionClick: function (cmp, event, helper) {
        console.log('%s, time: %f', 'handleTopFieldSetSectionClick', helper.timeStamp());
        if (event.currentTarget.id) {
            let topSections = cmp.get('v.topSections');
            topSections[event.currentTarget.id]['isOpen'] = !topSections[event.currentTarget.id]['isOpen'];
            cmp.set('v.topSections', topSections);
        }
    },

    handleBottomFieldSetSectionClick: function (cmp, event, helper) {
        console.log('%s, time: %f', 'handleBottomFieldSetSectionClick', helper.timeStamp());
        if (event.currentTarget.id) {
            let topSections = cmp.get('v.bottomSections');
            topSections[event.currentTarget.id]['isOpen'] = !topSections[event.currentTarget.id]['isOpen'];
            cmp.set('v.bottomSections', topSections);
        }
    }
})