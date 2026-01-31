#!/bin/bash
set -e  # Exit on error
# Check if mkdocs is installed
if ! command -v mkdocs &> /dev/null; then
    echo "Error: mkdocs is not installed"
    exit 1
fi

# Check if nim is installed
if ! command -v nim &> /dev/null; then
    echo "Error: nim is not installed"
    exit 1
fi

# Step 1: Build MkDocs documentation (Markdown -> HTML)
mkdocs build --clean --strict
if [ $? -ne 0 ]; then
    echo "Failed to build HTML documentation"
    exit 1
fi

# Step 2: Generate API documentation with NimDoc
mkdir -p docs/api

# Find nimdoc.css in standard locations
NIMDOC_PATH=""
for CHECK_PATH in "/usr/share/nim/doc" "/usr/local/lib/nim/doc" "/usr/lib/nim/doc"; do
    if [ -f "$CHECK_PATH/nimdoc.css" ]; then
        NIMDOC_PATH="$CHECK_PATH"
        break
    fi
done

if [ -z "$NIMDOC_PATH" ]; then
    echo "Warning: nimdoc.css not found in any standard location"
    echo "Skipping API documentation generation"
    echo "Searched locations: /usr/share/nim/doc, /usr/local/lib/nim/doc, /usr/lib/nim/doc"
    echo ""
    echo "===================================="
    echo "Documentation build complete (HTML only)!"
    echo ""
    echo "Output locations:"
    echo "  - HTML docs: docs/"
    echo ""
    echo "To view locally:"
    echo "  - Run: mkdocs serve"
    echo "  - Open: http://localhost:8000"
    echo ""
    exit 0
fi

# Try to create symlink or copy files to expected location
if [ "$NIMDOC_PATH" != "/usr/local/lib/nim/doc" ]; then
    # First, try to create a symlink (requires permissions)
    mkdir -p /usr/local/lib/nim/doc 2>/dev/null && \
    cp -f "$NIMDOC_PATH/nimdoc.css" /usr/local/lib/nim/doc/ 2>/dev/null && \
    cp -f "$NIMDOC_PATH/nimdoc.cls" /usr/local/lib/nim/doc/ 2>/dev/null || {
        # If that fails, copy nimdoc files to output directory
        echo "Note: Copying nimdoc files to output directory (no system permissions)"
        cp -f "$NIMDOC_PATH/nimdoc.css" docs/api/
        [ -f "$NIMDOC_PATH/nimdoc.cls" ] && cp -f "$NIMDOC_PATH/nimdoc.cls" docs/api/
    }
fi

# Generate API documentation
# Note: nim doc may print errors to stderr even when successful
nim doc --project --index:on --outdir:docs/api src/tzutrader.nim 2>&1 | \
    grep -v "^Hint:" | \
    grep -v "Warning: unknown substitution" | \
    grep -v "Error: unhandled exception: No such file or directory" | \
    grep -v "Additional info: .*/nimdoc.css" | \
    grep -v "oserrors.nim" | \
    grep -v "raiseOSError" || true

# Verify API docs were actually generated
if [ -f "docs/api/tzutrader.html" ] && [ -f "docs/api/index.html" ]; then
    echo "✓ API documentation generated successfully"
    echo "  Generated $(ls -1 docs/api/*.html 2>/dev/null | wc -l) HTML files"
else
    echo "✗ Warning: API documentation generation failed"
    echo "  HTML documentation is still available"
fi
