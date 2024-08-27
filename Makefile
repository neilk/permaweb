# Define directories

# Source files that have a more or less one-to-one relationship with the built files
SOURCE_DIR := source

# Source files that are special, like favicon images
METADATA_DIR := metadata

# Where the built files will go
BUILD_DIR := build
# Where the favicons will go
ICONS_DIR := $(BUILD_DIR)/icons



# Define the list(s) of files to build

# Find all HTML files in the source directory
HTML_FILES := $(shell find $(SOURCE_DIR) -type f -name '*.html')

# Find all image files in the source directory
IMAGE_FILES := $(shell find $(SOURCE_DIR) -type f \( -name '*.jpg' -o -name '*.jpeg' -o -name '*.gif' -o -name '*.png' \))

# Find all font files in the source directory
FONT_FILES := $(shell find $(SOURCE_DIR) -type f -name '*.ttf')

# Miscellaneous, icon files in SVG
SVG_FILES := $(shell find $(SOURCE_DIR) -type f -name '*.svg')

# Style
CSS_FILES := $(shell find $(SOURCE_DIR) -type f -name '*.css')

# Text
TXT_FILES := $(shell find $(SOURCE_DIR) -type f -name '*.txt')

# Generate the list of targets to build for HTML files
HTML_TARGETS := $(patsubst $(SOURCE_DIR)/%.html, $(BUILD_DIR)/%.html, $(HTML_FILES))

# Generate the list of targets to build for image files
IMAGE_TARGETS := $(patsubst $(SOURCE_DIR)/%, $(BUILD_DIR)/%, $(IMAGE_FILES))

# Generate the list of targets to build for font files
FONT_TARGETS := $(patsubst $(SOURCE_DIR)/%, $(BUILD_DIR)/%, $(FONT_FILES))

# Generate the list of targets to build for SVG files
SVG_TARGETS := $(patsubst $(SOURCE_DIR)/%, $(BUILD_DIR)/%, $(SVG_FILES))

# CSS targets
CSS_TARGETS := $(patsubst $(SOURCE_DIR)/%, $(BUILD_DIR)/%, $(CSS_FILES))

# TXT targets
TXT_TARGETS := $(patsubst $(SOURCE_DIR)/%, $(BUILD_DIR)/%, $(TXT_FILES))

# Favicon targets
FAVICON_SIZES := 16 32 96
FAVICON_TARGETS := $(addprefix $(BUILD_DIR)/icons/favicon-, $(addsuffix .png, $(FAVICON_SIZES)))

# Default target
all: $(HTML_TARGETS) $(IMAGE_TARGETS) $(FONT_TARGETS) $(SVG_TARGETS) $(FAVICON_TARGETS) $(CSS_TARGETS) $(TXT_TARGETS)

# Define a rule to process each HTML file
$(BUILD_DIR)/%.html: $(SOURCE_DIR)/%.html
	@mkdir -p $(dir $@)
	./permaweb $< > $@

# Rule to copy unmodified files 
$(BUILD_DIR)/%: $(SOURCE_DIR)/% $(IMAGE_FILES) $(FONT_FILES) $(SVG_FILES)
	@mkdir -p $(dir $@)
	cp $< $@

# Rule to create favicons
# the complex patsubst is needed to extract just the size from the target filename
FAVICON_SOURCE := $(METADATA_DIR)/favicon-source.png
$(BUILD_DIR)/icons/favicon-%: $(FAVICON_SOURCE)
	@mkdir -p $(ICONS_DIR)
	./favicons.sh $< $(patsubst $(ICONS_DIR)/favicon-%.png,%,$@) > $@


## TESTS 

# List of test directories
TEST_DIRS := $(filter %/, $(wildcard test/*/))

# Generate test targets for each test.sh script
TESTS := $(TEST_DIRS:%=%/test.sh)

# Default target to run all tests
test: $(TESTS)
	@echo "\nAll tests executed." >&2

# Pattern rule to run each test script
$(TESTS):
	@echo "\nRunning test $@" >&2
	@bash $@ || exit 1


# Clean build directory
clean:
	rm -rf $(BUILD_DIR)/*

# Phony targets
.PHONY: all clean test $(TESTS)
