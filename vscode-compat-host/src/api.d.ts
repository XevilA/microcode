export declare const microcodeShim: {
    commands: {
        registerCommand: (command: string, callback: (...args: any[]) => any) => {
            dispose: () => void;
        };
        executeCommand: (command: string, ...rest: any[]) => Promise<void>;
    };
    window: {
        showInformationMessage: (message: string) => Promise<void>;
        createOutputChannel: (name: string) => {
            appendLine: (val: string) => void;
            show: () => void;
            dispose: () => void;
        };
    };
    workspace: {
        getConfiguration: (section: string) => {
            get: (key: string, defaultValue?: any) => any;
        };
    };
};
//# sourceMappingURL=api.d.ts.map