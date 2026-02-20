export var PTHErrorCode;
(function (PTHErrorCode) {
    PTHErrorCode["NO_ACTIVE_SESSION"] = "NO_ACTIVE_SESSION";
    PTHErrorCode["SESSION_ALREADY_ACTIVE"] = "SESSION_ALREADY_ACTIVE";
    PTHErrorCode["BUILD_FAILED"] = "BUILD_FAILED";
    PTHErrorCode["GIT_ERROR"] = "GIT_ERROR";
    PTHErrorCode["PLUGIN_NOT_FOUND"] = "PLUGIN_NOT_FOUND";
    PTHErrorCode["INVALID_PLUGIN"] = "INVALID_PLUGIN";
    PTHErrorCode["INVALID_TEST"] = "INVALID_TEST";
    PTHErrorCode["RELOAD_FAILED"] = "RELOAD_FAILED";
    PTHErrorCode["CACHE_SYNC_FAILED"] = "CACHE_SYNC_FAILED";
})(PTHErrorCode || (PTHErrorCode = {}));
export class PTHError extends Error {
    code;
    context;
    constructor(code, message, context) {
        super(message);
        this.name = 'PTHError';
        this.code = code;
        this.context = context;
    }
}
//# sourceMappingURL=errors.js.map