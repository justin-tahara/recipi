// Safari runs this in the page someone shares to recipi, before the share
// sheet opens, and hands the result to the extension. recipi then reads
// the recipe from the page Safari already loaded (scripts run, bot checks
// passed) instead of downloading it again. Nothing leaves the device.
var SafariPage = function() {};

SafariPage.prototype = {
    run: function(parameters) {
        parameters.completionFunction({
            "url": document.URL,
            "html": document.documentElement.outerHTML
        });
    },

    finalize: function(parameters) {}
};

var ExtensionPreprocessingJS = new SafariPage;
