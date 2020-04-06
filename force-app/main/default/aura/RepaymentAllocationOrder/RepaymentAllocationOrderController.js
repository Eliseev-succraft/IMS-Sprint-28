({
    doInit: function (cmp, event, helper) {
        console.log('%s, time: %f', 'doInit', helper.timeStamp());
        let options = [];
        if (cmp.get('v.initStringOptions')) {

            console.log(cmp.get('v.initStringOptions'));
            let initStringOptions = cmp.get('v.initStringOptions').split(';');
            console.log(initStringOptions);

            if (initStringOptions.length > 0) {
                initStringOptions.forEach(function (option) {
                    if (option) {
                        options.push({
                            label: option,
                            bordered: false,
                            selected: false
                        });
                    }
                });
            }

        } else {
            let defaultOptions = [
                $A.get("$Label.c.amount_type_3"),
                $A.get("$Label.c.amount_type_2"),
                $A.get("$Label.c.amount_type_1"),
                $A.get("$Label.c.amount_type_4")
            ];
            defaultOptions.forEach(function (option) {
                options.push({
                    label: option,
                    bordered: false,
                    selected: false
                });
            });
        }
        cmp.set('v.options', options);
    },

    changeOptions: function (cmp, event, helper) {
        // console.log('%s, time: %f', 'changeOptions', helper.timeStamp());
        let outputString = '';
        if (event.getParam('value')) {
            event.getParam('value').forEach(function (option) {
                outputString += option.label + ';';
            });
            //console.log('outputString= ' + outputString);
            cmp.set('v.outputString', outputString);
        }
    },

    clickItem: function (cmp, event, helper) {
        console.group('%s, time: %f', 'clickItem', helper.timeStamp());
        if (!cmp.get('v.disabled')) {
            if (event.currentTarget.id) {
                cmp.set('v.selectedItem', event.currentTarget.id);
                helper.resetOptions(cmp);
            }
        }
        console.groupEnd();
    },

    clickMoveUp: function (cmp, event, helper) {
        console.log('%s, time: %f', 'clickMoveUp', helper.timeStamp());
        if (cmp.get('v.selectedItem') != null) {
            let index = parseInt(cmp.get('v.selectedItem'));
            let options = cmp.get('v.options');
            if (options[index]) {
                if (index !== 0) {
                    let item = options[index - 1];
                    options.splice(index - 1, 1, options[index]);
                    options.splice(index, 1, item);
                    cmp.set('v.options', options);
                    cmp.set('v.selectedItem', index - 1);
                }
            }

        }
    },

    clickMoveDown: function (cmp, event, helper) {
        console.log('%s, time: %f', 'clickMoveDown', helper.timeStamp());
        if (cmp.get('v.selectedItem') != null) {
            let index = parseInt(cmp.get('v.selectedItem'));
            let options = cmp.get('v.options');
            console.log(options);
            if (options[index]) {
                if (index !== options.length - 1) {
                    let item = options[index + 1];
                    options.splice(index + 1, 1, options[index]);
                    options.splice(index, 1, item);
                    cmp.set('v.options', options);
                    cmp.set('v.selectedItem', index + 1);
                }
            }
        }
    },

    dragStart: function (cmp, event, helper) {
        console.log('%s, time: %f', 'dragStart', helper.timeStamp());
        if (!cmp.get('v.disabled')) {
            helper.resetOptions(cmp);
            if (event.currentTarget.id) {
                cmp.set('v.selectedItem', event.currentTarget.id);
                helper.resetOptions(cmp);
                event.dataTransfer.setData("text", event.currentTarget.id);
            }
        }
    },

    drag: function (cmp, event, helper) {
        // console.log('%s, time: %f', 'drag', helper.timeStamp());
        if (!cmp.get('v.disabled')) {
            let options = cmp.get('v.options');
            let oldIndex = cmp.get('v.selectedItem');
            let newIndex = event.target.closest('[id]').id;
            if (oldIndex != null && newIndex != null) {
                if (options[newIndex] != null && options[oldIndex] != null) {
                    let item = options[newIndex];
                    options.splice(newIndex, 1, options[oldIndex]);
                    options.splice(oldIndex, 1, item);
                    cmp.set('v.options', options);
                    cmp.set('v.selectedItem', newIndex);
                    helper.resetOptions(cmp);
                }
            }
        }
        event.preventDefault();
    }
})