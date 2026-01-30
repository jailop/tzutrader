#!/bin/bash
# Serve TzuTrader Documentation Locally
# This script starts a local web server for previewing documentation

set -e  # Exit on error

echo "Starting TzuTrader Documentation Server..."
echo "=========================================="
echo ""

# Check if mkdocs is installed
if ! command -v mkdocs &> /dev/null; then
    echo "Error: mkdocs is not installed"
    echo "Install with: pip install mkdocs mkdocs-material pymdown-extensions mkdocs-minify-plugin"
    exit 1
fi

echo "Starting local server at http://localhost:8000"
echo ""
echo "The server will automatically rebuild documentation when you edit files."
echo "Press Ctrl+C to stop the server."
echo ""

mkdocs serve
