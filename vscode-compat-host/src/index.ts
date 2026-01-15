
import * as readline from 'readline';
import { microcodeShim } from './api';

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    terminal: false
});

// Polyfill global vscode
(global as any).vscode = microcodeShim;

console.error("MicroCode Compat Host Started");

rl.on('line', (line: string) => {
    if (!line.trim()) return;
    try {
        const msg = JSON.parse(line);
        handleMessage(msg);
    } catch (e) {
        console.error("Failed to parse message:", e);
    }
});

function handleMessage(msg: any) {
    if (msg.method === 'ext/load') {
        const { path } = msg.params;
        try {
            console.error(`Loading extension at: ${path}`);
            // Dynamic require to activate extension
            // In a real implementation this would read package.json and call "activate"
            const extension = require(path);
            if (extension.activate) {
                // Mock context
                const context = { subscriptions: [] };
                extension.activate(context);
                sendResponse(msg.id, { status: 'activated' });
            } else {
                sendError(msg.id, -32000, "No activate function found");
            }
        } catch (e: any) {
            sendError(msg.id, -32000, `Failed to load: ${e.message}`);
        }
    }
}

function sendResponse(id: number, result: any) {
    console.log(JSON.stringify({
        jsonrpc: "2.0",
        id,
        result
    }));
}

function sendError(id: number, code: number, message: string) {
    console.log(JSON.stringify({
        jsonrpc: "2.0",
        id,
        error: { code, message }
    }));
}
