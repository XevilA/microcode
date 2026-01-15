"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
const readline = __importStar(require("readline"));
const api_1 = require("./api");
const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    terminal: false
});
// Polyfill global vscode
global.vscode = api_1.microcodeShim;
console.error("MicroCode Compat Host Started");
rl.on('line', (line) => {
    if (!line.trim())
        return;
    try {
        const msg = JSON.parse(line);
        handleMessage(msg);
    }
    catch (e) {
        console.error("Failed to parse message:", e);
    }
});
function handleMessage(msg) {
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
            }
            else {
                sendError(msg.id, -32000, "No activate function found");
            }
        }
        catch (e) {
            sendError(msg.id, -32000, `Failed to load: ${e.message}`);
        }
    }
}
function sendResponse(id, result) {
    console.log(JSON.stringify({
        jsonrpc: "2.0",
        id,
        result
    }));
}
function sendError(id, code, message) {
    console.log(JSON.stringify({
        jsonrpc: "2.0",
        id,
        error: { code, message }
    }));
}
//# sourceMappingURL=index.js.map