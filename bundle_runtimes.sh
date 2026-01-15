#!/bin/bash
# bundle_runtimes.sh
# Downloads and bundles portable runtimes into the app bundle (Specific Architecture)

set -e

APP_BUNDLE="${1}"
TARGET_ARCH="${2}" # "arm64" or "x86_64"

if [ -z "$APP_BUNDLE" ] || [ -z "$TARGET_ARCH" ]; then
    echo "Usage: ./bundle_runtimes.sh <AppBundlePath> <Architecture>"
    exit 1
fi

RUNTIMES_ROOT="${APP_BUNDLE}/Contents/Resources/RuntimeLib"

echo "🔧 Bundling Runtimes for ${TARGET_ARCH}..."
echo "   Target: ${RUNTIMES_ROOT}"

mkdir -p "${RUNTIMES_ROOT}"
mkdir -p ".runtime_cache"

# MARK: - Node.js
bundle_nodejs() {
    ARCH=$1
    echo "   📦 Node.js (${ARCH})..."
    
    if [ "$ARCH" = "arm64" ]; then
        NODE_URL="https://nodejs.org/dist/v20.10.0/node-v20.10.0-darwin-arm64.tar.gz"
    else
        NODE_URL="https://nodejs.org/dist/v20.10.0/node-v20.10.0-darwin-x64.tar.gz"
    fi
    
    CACHE_FILE=".runtime_cache/nodejs-${ARCH}.tar.gz"
    
    if [ ! -f "$CACHE_FILE" ]; then
        echo "      Downloading..."
        curl -L -o "$CACHE_FILE" "$NODE_URL" --silent
    fi
    
    # Extract to Runtimes/nodejs (no sub-arch folder needed since app is single arch)
    TARGET_DIR="${RUNTIMES_ROOT}/nodejs"
    rm -rf "${TARGET_DIR}"
    mkdir -p "${TARGET_DIR}"
    tar -xzf "$CACHE_FILE" -C "${TARGET_DIR}" --strip-components=1
}

# MARK: - Go
bundle_go() {
    ARCH=$1
    echo "   📦 Go (${ARCH})..."
    
    if [ "$ARCH" = "arm64" ]; then
        GO_URL="https://go.dev/dl/go1.21.5.darwin-arm64.tar.gz"
    else
        GO_URL="https://go.dev/dl/go1.21.5.darwin-amd64.tar.gz"
    fi
    
    CACHE_FILE=".runtime_cache/go-${ARCH}.tar.gz"
    
    if [ ! -f "$CACHE_FILE" ]; then
        echo "      Downloading..."
        curl -L -o "$CACHE_FILE" "$GO_URL" --silent
    fi
    
    TARGET_DIR="${RUNTIMES_ROOT}/go"
    rm -rf "${TARGET_DIR}"
    mkdir -p "${TARGET_DIR}"
    tar -xzf "$CACHE_FILE" -C "${TARGET_DIR}" --strip-components=1
}

# MARK: - Python (Portable)
bundle_python() {
    ARCH=$1
    echo "   📦 Python (${ARCH})..."
    
    # Use python-build-standalone for portable Python
    if [ "$ARCH" = "arm64" ]; then
        PYTHON_URL="https://github.com/indygreg/python-build-standalone/releases/download/20231002/cpython-3.11.6+20231002-aarch64-apple-darwin-install_only.tar.gz"
    else
        PYTHON_URL="https://github.com/indygreg/python-build-standalone/releases/download/20231002/cpython-3.11.6+20231002-x86_64-apple-darwin-install_only.tar.gz"
    fi
    
    CACHE_FILE=".runtime_cache/python-${ARCH}.tar.gz"
    
    if [ ! -f "$CACHE_FILE" ]; then
        echo "      Downloading..."
        curl -L -o "$CACHE_FILE" "$PYTHON_URL" --silent
    fi
    
    TARGET_DIR="${RUNTIMES_ROOT}/python"
    rm -rf "${TARGET_DIR}"
    mkdir -p "${TARGET_DIR}"
    tar -xzf "$CACHE_FILE" -C "${TARGET_DIR}" --strip-components=1
}

# MARK: - Rust (Mini)
bundle_rust() {
    ARCH=$1
    echo "   📦 Rust tools (${ARCH}) - Skipping (relying on system/extensions)"
}

# MARK: - Main
main() {
    echo "========================================"
    echo "  MicroCode Runtime Bundler (${TARGET_ARCH})"
    echo "========================================"
    
    bundle_nodejs "$TARGET_ARCH"
    bundle_go "$TARGET_ARCH"
    bundle_python "$TARGET_ARCH"
    bundle_rust "$TARGET_ARCH"
    
    # Show sizes
    echo ""
    echo "📊 Bundle Sizes:"
    du -sh "${RUNTIMES_ROOT}"/* 2>/dev/null || true
    
    echo ""
    echo "✅ Runtime bundling complete!"
    echo "   Total size: $(du -sh "${RUNTIMES_ROOT}" | cut -f1)"
}

# Run
main
