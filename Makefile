MAKE_START_TIME := $(shell date "+%Y%m%d%H%M.%S")

# If Make was invoked with debugging, pass along a debug flag to the scripts
export DEBUG=$(if $(findstring d,$(MAKEFLAGS)),-d)

# Define directories

# Source files that have a more or less one-to-one relationship with the built files
SOURCE_DIR := source

# Source files that are special, like favicon images
METADATA_DIR := metadata

# Where the built files will go
BUILD_DIR := build
# Where the favicons will go
ICONS_DIR := $(BUILD_DIR)/icons


# In case we are being called from some other directory?
MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
MKFILE_DIR := $(realpath $(dir $(MKFILE_PATH)))
TMP_FINAL_TARGET = $(MKFILE_DIR)/.tmp


# Define the list(s) of files to build

# Find all HTML files in the source directory
HTML_FILES := $(shell find $(SOURCE_DIR) -type f -name '*.html')

# Find all image files in the source directory
IMAGE_FILES := $(shell find $(SOURCE_DIR) -type f \( -name '*.jpg' -o -name '*.jpeg' -o -name '*.gif' -o -name '*.png' \))

# Find all font files in the source directory
FONT_FILES := $(shell find $(SOURCE_DIR) -type f -name '*.ttf')

# Miscellaneous, icon files in SVG
SVG_FILES := $(shell find $(SOURCE_DIR) -type f -name '*.svg')

# PDFs
PDF_FILES := $(shell find $(SOURCE_DIR) -type f -name '*.pdf')

# Style
CSS_FILES := $(shell find $(SOURCE_DIR) -type f -name '*.css')

# Text
TXT_FILES := $(shell find $(SOURCE_DIR) -type f -name '*.txt')

# JavaScript
JS_FILES := $(shell find $(SOURCE_DIR) -type f -name '*.js')

# Generate the list of targets to build for HTML files
HTML_TARGETS := $(patsubst $(SOURCE_DIR)/%.html, $(BUILD_DIR)/%.html, $(HTML_FILES))

# Generate the list of targets to build for image files
IMAGE_TARGETS := $(patsubst $(SOURCE_DIR)/%, $(BUILD_DIR)/%, $(IMAGE_FILES))

# Generate the list of targets to build for font files
FONT_TARGETS := $(patsubst $(SOURCE_DIR)/%, $(BUILD_DIR)/%, $(FONT_FILES))

# Generate the list of targets to build for SVG files
SVG_TARGETS := $(patsubst $(SOURCE_DIR)/%, $(BUILD_DIR)/%, $(SVG_FILES))

# Generate the list of targets to build for SVG files
PDF_TARGETS := $(patsubst $(SOURCE_DIR)/%, $(BUILD_DIR)/%, $(PDF_FILES))

# CSS targets
CSS_TARGETS := $(patsubst $(SOURCE_DIR)/%, $(BUILD_DIR)/%, $(CSS_FILES))

# TXT targets
TXT_TARGETS := $(patsubst $(SOURCE_DIR)/%, $(BUILD_DIR)/%, $(TXT_FILES))

# JS targets
JS_TARGETS := $(patsubst $(SOURCE_DIR)/%, $(BUILD_DIR)/%, $(JS_FILES))


# Sized favicon PNG targets. You'll need meta tags in your HTML to use these.
FAVICON_SIZES := 16 32 96
FAVICON_TARGETS := $(addprefix $(BUILD_DIR)/icons/favicon-, $(addsuffix .png, $(FAVICON_SIZES)))
# Traditional favicon.ico target
FAVICON_ICO_TARGET := $(BUILD_DIR)/favicon.ico

# This is going to run in its entirety on every build. 
# This is going to rely significantly on caching if it's going to be fast.
# This will fail if the build directory doesn't exist... because we don't know where it is, we're delegating that to reduce.sh
mapreduce:
	$(MKFILE_DIR)/reduce.sh $(SOURCE_DIR)


file_targets: $(HTML_TARGETS) $(IMAGE_TARGETS) $(FONT_TARGETS) $(SVG_TARGETS) $(PDF_TARGETS) $(FAVICON_TARGETS) $(FAVICON_ICO_TARGET) $(CSS_TARGETS) $(TXT_TARGETS) $(JS_TARGETS)

# Default target
all: file_targets mapreduce

# Define a rule to process each HTML file
# 
# single.sh runs a pipeline of scripts a single file, which produces an identically named output file.
#
# We do it in a bit more complicated way here to support "live" editing.
#
# We write to a temporary final target because if we begin writing to the actual target, it will temporarily 
# be the empty file. If processing never emits anything, it will stay as an empty file. 
#
# Also, often a user will be developing with a "watch" script to reload a changed file, 
# and we don't want them to load an empty file into their browser. 
#
# Finally we fiddle with the mtime of the target file to match the invocation of this Makefile.
# This ensures that if the source files change while this Makefile is running,
# a subsequent invocation of `make` will notice the targets are out of date.
#
# TODO: maybe the script should handle tempfiles itself?
$(BUILD_DIR)/%.html: $(SOURCE_DIR)/%.html
	@mkdir -p $(dir $@)

	$(MKFILE_DIR)/single.sh -d $< > $(TMP_FINAL_TARGET)
	
	$(shell touch -t $(MAKE_START_TIME) $(TMP_FINAL_TARGET))
	
	# And atomically update our actual target
	mv $(TMP_FINAL_TARGET) $@


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
$(FAVICON_ICO_TARGET): $(FAVICON_TARGETS)
	magick $(FAVICON_SOURCE) -resize "32x32" $@

## TESTS 

# List of test directories
TEST_DIRS := $(filter %/, $(wildcard test/*/))

# Generate test targets for each test.sh script
TESTS := $(TEST_DIRS:%=%test.sh)

# Test the testing library itself
test-lib-test:
	@echo "\nTesting the testing library..." >&2
	@echo "Running passing tests..." >&2
	@bash test/lib-test-passing.sh || exit 1
	@echo "Running eval tests..." >&2
	@bash test/lib-test-eval.sh || exit 1
	@echo "Testing failure detection..." >&2
	@bash test/lib-test-failing.sh && echo "ERROR: Failing test should have failed!" && exit 1 || echo "✓ Failure detection works correctly"

# Default target to run all tests
test: $(TESTS) test-lib-test
	@echo "\n" >&2
	@echo "==============================" >&2
	@echo "All tests passed successfully." >&2

# Pattern rule to run each test script
$(TESTS):
	@echo "\nRunning test $@" >&2
	@bash $@ || exit 1

SOURCES := $(HTML_FILES) $(IMAGE_FILES) $(FONT_FILES) $(SVG_FILES) $(FAVICON_SOURCE) $(CSS_FILES) $(TXT_FILES)
sources:
	$(info $(SOURCES))

# Clean build directory
clean:
	rm -rf $(BUILD_DIR)/*

# Phony targets
.PHONY: all clean test mapreduce test-lib-test $(TESTS)
