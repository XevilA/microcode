
export const microcodeShim = {
    commands: {
        registerCommand: (command: string, callback: (...args: any[]) => any) => {
            console.error(`[Shim] Registered command: ${command}`);
            // In real impl: notify Core to register command ID
            return { dispose: () => { } };
        },
        executeCommand: (command: string, ...rest: any[]) => {
            console.error(`[Shim] Executing command: ${command}`);
            return Promise.resolve();
        }
    },
    window: {
        showInformationMessage: (message: string) => {
            console.error(`[Shim] Info: ${message}`);
            // Send RPC to Core
            return Promise.resolve();
        },
        createOutputChannel: (name: string) => {
            return {
                appendLine: (val: string) => console.error(`[${name}] ${val}`),
                show: () => { },
                dispose: () => { }
            };
        }
    },
    workspace: {
        getConfiguration: (section: string) => {
            return {
                get: (key: string, defaultValue?: any) => defaultValue
            };
        }
    }
};
