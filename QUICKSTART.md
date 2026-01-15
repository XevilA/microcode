# CodeTunner Quick Start Guide

Get up and running with CodeTunner in 5 minutes!

## 📋 Prerequisites

Before you begin, ensure you have:

- macOS 13.0 or later
- Xcode 15.0+ (from Mac App Store)
- Rust 1.70+ 
- Python 3.x (usually pre-installed on macOS)
- Node.js (optional, for JavaScript execution)

## 🚀 Installation

### Step 1: Install Rust

If you don't have Rust installed:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
```

Verify installation:
```bash
rustc --version
cargo --version
```

### Step 2: Clone or Navigate to Project

```bash
cd SX/codetunner-native
```

### Step 3: Set Up AI API Keys

Choose one or more AI providers and set up your API keys:

**Option A: Environment Variables (Recommended)**
```bash
# Add to your ~/.zshrc or ~/.bash_profile
export GEMINI_API_KEY="your-gemini-api-key-here"
export OPENAI_API_KEY="your-openai-api-key-here"
export ANTHROPIC_API_KEY="your-anthropic-api-key-here"

# Reload your shell
source ~/.zshrc  # or source ~/.bash_profile
```

**Option B: .env File**
```bash
cd backend
cat > .env << EOF
GEMINI_API_KEY=your-gemini-api-key-here
OPENAI_API_KEY=your-openai-api-key-here
ANTHROPIC_API_KEY=your-anthropic-api-key-here
EOF
cd ..
```

**Getting API Keys:**
- **Gemini**: https://makersuite.google.com/app/apikey
- **OpenAI**: https://platform.openai.com/api-keys
- **Claude**: https://console.anthropic.com/account/keys

### Step 4: Build the Backend

```bash
cd backend
cargo build --release
```

This may take a few minutes on the first build as it downloads and compiles dependencies.

### Step 5: Start the Backend

```bash
cargo run --release
```

You should see:
```
INFO CodeTunner Backend v2.0.0
INFO Backend listening on 127.0.0.1:8080
```

Keep this terminal open!

### Step 6: Create the Xcode Project

Open a new terminal and navigate to the project root:

```bash
cd SX/codetunner-native
```

**Create Xcode Project:**

1. Open Xcode
2. File → New → Project
3. Select **macOS** → **App**
4. Configure:
   - Product Name: `CodeTunner`
   - Interface: `SwiftUI`
   - Language: `Swift`
   - Save in: `SX/codetunner-native/` (root of the project)

5. Add Source Files:
   - Right-click on `CodeTunner` group in Xcode
   - Add Files to "CodeTunner"...
   - Select all `.swift` files from `CodeTunner/` directory
   - Check "Copy items if needed"
   - Create groups

6. Project Settings:
   - Select CodeTunner project
   - General → Minimum Deployments: macOS 13.0
   - Signing & Capabilities → Enable "Outgoing Connections (Client)"

### Step 7: Run the Frontend

1. In Xcode, select the CodeTunner scheme
2. Press ⌘R to build and run

The app should launch! 🎉

## 🎯 First Steps

### Create Your First File

1. Click **"New File"** or press ⌘N
2. Start typing your code
3. Press ⌘S to save

### Open a Project

1. Click **"Open Folder"** or press ⌘⇧O
2. Select a folder containing code
3. Browse files in the sidebar

### Run Code

1. Open a Python or JavaScript file
2. Press ⌘R to run
3. See output in the console (press ⌘⌥J if not visible)

### Try AI Features

1. Write or paste some code
2. Press ⌘⌥R to refactor with AI
3. Enter instructions like "Add error handling" or "Optimize this code"
4. Press ⌘⌥E to get an AI explanation of your code

### Use Git

1. Open a Git repository folder
2. Press ⌘⌥G to show Git panel
3. View changes, commit, push, and pull

## 🎨 Customization

### Change Font Size
- Increase: ⌘+
- Decrease: ⌘-
- Reset: ⌘0

### Toggle Panels
- Sidebar: ⌘⌥B
- Console: ⌘⌥J
- Git Panel: ⌘⌥G

### Switch AI Provider
1. Open Settings (⌘,)
2. Go to AI tab
3. Select your preferred provider
4. Enter API key if not already set

## 🐛 Troubleshooting

### Backend Won't Start

**Problem:** Port 8080 already in use
```bash
# Find what's using port 8080
lsof -i :8080
# Kill the process
kill -9 <PID>
```

**Problem:** Compilation errors
```bash
# Clean and rebuild
cd backend
cargo clean
cargo build --release
```

### Frontend Build Errors

**Problem:** Missing files
- Ensure all `.swift` files are added to the Xcode project
- Check Build Phases → Compile Sources

**Problem:** API connection failed
- Verify backend is running on port 8080
- Check Console logs in Xcode

### AI Features Not Working

**Problem:** "API key not found"
- Verify environment variables are set
- Restart the backend after setting keys
- Check .env file exists and is correct

**Problem:** "Connection refused"
- Ensure backend server is running
- Check firewall settings

### Code Execution Fails

**Problem:** "python3 not found"
```bash
# Install Python if needed
brew install python3
```

**Problem:** "node not found"
```bash
# Install Node.js
brew install node
```

## 📚 Next Steps

Now that you're up and running, explore these features:

1. **Code Analysis**: Open any file and see real-time analysis
2. **Format Code**: Press ⌘⌥I to auto-format
3. **Git Integration**: Full Git workflow built-in
4. **Multiple Tabs**: Open multiple files in tabs
5. **AI Assistance**: Use AI to explain, refactor, or complete code

## 🎓 Keyboard Shortcuts Cheat Sheet

| Action | Shortcut |
|--------|----------|
| New File | ⌘N |
| Open File | ⌘O |
| Open Folder | ⌘⇧O |
| Save | ⌘S |
| Save As | ⌘⇧S |
| Run Code | ⌘R |
| Stop Execution | ⌘. |
| Format Code | ⌘⌥I |
| Refactor with AI | ⌘⌥R |
| Explain Code | ⌘⌥E |
| Toggle Sidebar | ⌘⌥B |
| Toggle Console | ⌘⌥J |
| Toggle Git Panel | ⌘⌥G |
| Git Commit | ⌘K |
| Git Push | ⌘⇧P |
| Git Pull | ⌘⌥P |
| Increase Font | ⌘+ |
| Decrease Font | ⌘- |
| Reset Font | ⌘0 |

## 💡 Pro Tips

1. **Keep Backend Running**: Always keep the backend server running while using the app
2. **Use .env Files**: Store API keys in .env for easy management
3. **Git Integration**: Work directly with Git - no terminal needed
4. **Multiple AI Providers**: Try different providers for different tasks
5. **Keyboard Shortcuts**: Learn shortcuts to boost productivity

## 🆘 Getting Help

- **Documentation**: See [README.md](README.md) for full documentation
- **Issues**: Report bugs on GitHub
- **Email**: contact@aipreneur.club
- **Community**: Join our Discord (coming soon)

## 🎉 You're All Set!

Congratulations! You're ready to use CodeTunner. 

Happy coding! 🚀

---

**Made with ❤️ by SPU AI CLUB**