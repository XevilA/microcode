"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.microcodeShim = void 0;
exports.microcodeShim = {
    commands: {
        registerCommand: (command, callback) => {
            console.error(`[Shim] Registered command: ${command}`);
            // In real impl: notify Core to register command ID
            return { dispose: () => { } };
        },
        executeCommand: (command, ...rest) => {
            console.error(`[Shim] Executing command: ${command}`);
            return Promise.resolve();
        }
    },
    window: {
        showInformationMessage: (message) => {
            console.error(`[Shim] Info: ${message}`);
            // Send RPC to Core
            return Promise.resolve();
        },
        createOutputChannel: (name) => {
            return {
                appendLine: (val) => console.error(`[${name}] ${val}`),
                show: () => { },
                dispose: () => { }
            };
        }
    },
    workspace: {
        getConfiguration: (section) => {
            return {
                get: (key, defaultValue) => defaultValue
            };
        }
    }
};
//# sourceMappingURL=api.js.map