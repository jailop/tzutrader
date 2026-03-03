# Makefile for tzutrader documentation
# Builds both user documentation (mkdocs) and API reference (doxygen)

.PHONY: all docs api clean help

# Default target
all: docs api

# Build user documentation with mkdocs
docs:
	@echo "Building user documentation with mkdocs..."
	@if command -v mkdocs >/dev/null 2>&1; then \
		mkdocs build; \
		echo "User documentation built successfully in ./docs/"; \
	else \
		echo "Error: mkdocs not found. Install with: pip install mkdocs"; \
		exit 1; \
	fi

# Build API reference with doxygen
api:
	@echo "Building API reference with doxygen..."
	@if command -v doxygen >/dev/null 2>&1; then \
		doxygen Doxyfile; \
		echo "API reference built successfully in ./docs/html/"; \
	else \
		echo "Error: doxygen not found. Install with: apt install doxygen (or equivalent)"; \
		exit 1; \
	fi

# Serve documentation locally (requires mkdocs)
serve:
	@echo "Starting local documentation server..."
	@echo "User docs will be at http://127.0.0.1:8000/"
	@echo "API docs will be at http://127.0.0.1:8000/html/"
	@if command -v mkdocs >/dev/null 2>&1; then \
		mkdocs serve; \
	else \
		echo "Error: mkdocs not found. Install with: pip install mkdocs"; \
		exit 1; \
	fi

# Clean generated documentation
clean:
	@echo "Cleaning generated documentation..."
	@rm -rf docs/
	@echo "Documentation cleaned."

# Rebuild everything from scratch
rebuild: clean all

# Display help
help:
	@echo "tzutrader Documentation Build System"
	@echo ""
	@echo "Available targets:"
	@echo "  all      - Build both user docs and API reference (default)"
	@echo "  docs     - Build user documentation (mkdocs)"
	@echo "  api      - Build API reference (doxygen)"
	@echo "  serve    - Start local documentation server"
	@echo "  clean    - Remove generated documentation"
	@echo "  rebuild  - Clean and rebuild all documentation"
	@echo "  help     - Show this help message"
	@echo ""
	@echo "Requirements:"
	@echo "  - mkdocs:  pip install mkdocs"
	@echo "  - doxygen: apt install doxygen (or equivalent)"
	@echo ""
	@echo "Output locations:"
	@echo "  - User docs: ./docs/"
	@echo "  - API docs:  ./docs/html/"
	@echo ""
	@echo "Online documentation:"
	@echo "  - User Guide: https://jailop.codeberg.page/tzutrader/docs/"
	@echo "  - API Reference: https://jailop.codeberg.page/tzutrader/docs/html/"
