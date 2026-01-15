#!/bin/bash
set -e

echo "🚀 Building MicroCode Extension System..."

# 1. Build Extension Host (Rust)
echo "📦 Building extension-host..."
cd extension-host
cargo build
cd ..

# 2. Build MicroCode Ext CLI (Rust)
echo "🛠️ Building microcode-ext CLI..."
cd microcode-ext
cargo build
cd ..

# 3. Build VSCode Compat Host (Node)
echo "🟢 Building vscode-compat-host..."
cd vscode-compat-host
npm install
npx tsc
cd ..

echo "✅ Extension System Build Complete!"
echo "   - Host: extension-host/target/debug/extension-host"
echo "   - CLI:  microcode-ext/target/debug/microcode-ext"
echo "   - Node: vscode-compat-host/dist/index.js"
