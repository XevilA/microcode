#!/bin/bash
# =============================================================================
# MicroCode - SHA256 Checksum Generator
# สร้าง Checksum สำหรับ Source Files ทั้งหมด
# ใช้สำหรับตรวจสอบความถูกต้องและป้องกัน Malware
# =============================================================================

set -e

CHECKSUM_FILE="CHECKSUMS.sha256"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔐 MicroCode SHA256 Checksum Generator"
echo "======================================"

# ลบไฟล์เก่า
rm -f "$CHECKSUM_FILE"

# สร้าง Checksums สำหรับ Swift, Rust, ObjC++, และ Config Files
echo "📁 Generating checksums for source files..."

# Swift Sources
find CodeTunner -name "*.swift" -type f | sort | while read file; do
    shasum -a 256 "$file" >> "$CHECKSUM_FILE"
done

# ObjC++ Sources (CodeTunnerSupport)
find CodeTunnerSupport -name "*.mm" -o -name "*.m" -o -name "*.h" -type f 2>/dev/null | sort | while read file; do
    shasum -a 256 "$file" >> "$CHECKSUM_FILE"
done

# Rust Sources
find backend/src -name "*.rs" -type f 2>/dev/null | sort | while read file; do
    shasum -a 256 "$file" >> "$CHECKSUM_FILE"
done

# Extension Host (Rust)
find extension-host/src -name "*.rs" -type f 2>/dev/null | sort | while read file; do
    shasum -a 256 "$file" >> "$CHECKSUM_FILE"
done

# VSCode Compat Host (TypeScript/JS)
find vscode-compat-host/src -name "*.ts" -o -name "*.js" -type f 2>/dev/null | sort | while read file; do
    shasum -a 256 "$file" >> "$CHECKSUM_FILE"
done

# Critical Config Files
for config in Package.swift Cargo.toml build.sh; do
    if [ -f "$config" ]; then
        shasum -a 256 "$config" >> "$CHECKSUM_FILE"
    fi
    if [ -f "backend/$config" ]; then
        shasum -a 256 "backend/$config" >> "$CHECKSUM_FILE"
    fi
done

# Count entries
COUNT=$(wc -l < "$CHECKSUM_FILE" | tr -d ' ')

echo ""
echo "✅ Generated $COUNT checksums"
echo "📄 Saved to: $CHECKSUM_FILE"
echo ""
echo "🔐 To verify: ./verify_checksums.sh"
