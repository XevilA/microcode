const vscode = require('vscode');

function activate(context) {
    console.log('Congratulations, your extension "vscode-hello" is now active!');

    let disposable = vscode.commands.registerCommand('hello.vscode', function () {
        vscode.window.showInformationMessage('Hello MicroCode from VS Code Extension!');
    });

    context.subscriptions.push(disposable);
}

function deactivate() { }

module.exports = {
    activate,
    deactivate
}
