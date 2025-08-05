MAKE_START_TIME := $(shell date "+%Y%m%d%H%M.%S")

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

# Movies
MOVIE_FILES := $(shell find $(SOURCE_DIR) -type f \( -name '*.mp4' -o -name '*.webm' \))

# A list of all source files
ALL_FILES := $(HTML_FILES) $(IMAGE_FILES) $(FONT_FILES) $(SVG_FILES) $(PDF_FILES) $(CSS_FILES) $(TXT_FILES) $(JS_FILES) $(MOVIE_FILES)

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

# Movie targets
MOVIE_TARGETS := $(patsubst $(SOURCE_DIR)/%, $(BUILD_DIR)/%, $(MOVIE_FILES))

# All targets 
ALL_FILE_TARGETS := $(HTML_TARGETS) $(IMAGE_TARGETS) $(FONT_TARGETS) $(SVG_TARGETS) $(PDF_TARGETS) $(CSS_TARGETS) $(TXT_TARGETS) $(JS_TARGETS) $(MOVIE_TARGETS)

# Sized favicon PNG targets. You'll need meta tags in your HTML to use these.
FAVICON_SIZES := 16 32 96
FAVICON_TARGETS := $(addprefix $(BUILD_DIR)/icons/favicon-, $(addsuffix .png, $(FAVICON_SIZES)))
# Traditional favicon.ico target
FAVICON_ICO_TARGET := $(BUILD_DIR)/favicon.ico


####################################################################################################### 
# DYNAMICALLY GENERATED RULES

# We have the concept of "map-reduce" targets. For instance, if we want to express that every time an HTML file 
# changes, we want to process it into an RSS file, we can do that by creating a directory structure like this:
# reducers/
#   html/
#     feeds/
#       rss.xml/
#          map.sh
#          reduce 
#            main.sh
#            rss.xml.template
# 
# Note that within the rss.xml directory, we could have a `map` subdirectory or a `map.*` file.
# 
# So here we will dynamically generate rules from these directories. Basically we will depend on `reduce.sh` doing the 
# right thing (it will find files all over again, maybe we could fix that), but we will only invoke it when certain files change.

# Establish what the map-reduce targets are. In our example above, it would be $(BUILD_DIR)/feeds/rss.xml.

ifneq ($(wildcard reducers),)   # REDUCERS check: if we look for reducers/ , and find it is not empty

MAPREDUCE_TARGETS := $(shell find reducers -type d | while read dir; do \
	if [[ -d "$$dir/map" ]] || ls "$$dir"/map.* >/dev/null 2>&1; then \
		echo "$$dir"; \
	fi; \
done | sed 's|^reducers/[^/]*/|$(BUILD_DIR)/|')

# Helper function to convert extension to uppercase for variable names
to_upper = $(shell echo $(1) | tr '[:lower:]' '[:upper:]')

# Function to create mapreduce rule for a specific reducer directory. If any HTML file changes, or if 
# any of the scripts to do the map-reduce processing change, then the target will be rebuilt.
#   e.g. given        
#      "reducers/html/feeds/rss.xml" and relative target "feeds/rss.xml"
#   it creates:  
#      $(BUILD_DIR)/feeds/rss.xml: $(HTML_FILES) reducers/html/feeds/rss.xml/%
#        $(MKFILE_DIR)/reduce-target.sh -s $(SOURCE_DIR) -e html -m reducers/html/feeds/rss.xml/map.js -r reducers/html/feeds/rss.xml/reduce.sh -t $(BUILD_DIR)/feeds/rss.xml
define create_mapreduce_rule
$(BUILD_DIR)/$(3): $($(call to_upper,$(2))_FILES) $(wildcard $(1)/*)
	@$(MKFILE_DIR)/reduce-target.sh -s $(SOURCE_DIR) -e $(2) -m $(4) -r $(5) -t $(BUILD_DIR)/$(3)
endef

# Apply the function to each reducer directory to create individual rules
$(foreach rule_info,$(shell $(MKFILE_DIR)/find-map-reduce.sh), \
$(eval $(call create_mapreduce_rule,$(word 1,$(subst |, ,$(rule_info))),$(word 2,$(subst |, ,$(rule_info))),$(word 3,$(subst |, ,$(rule_info))),$(word 4,$(subst |, ,$(rule_info))),$(word 5,$(subst |, ,$(rule_info))))))

endif  # end REDUCERS check

# ?? obsolete - this rule is very simple, not dynamic, but might work more robustly
# MAPREDUCE_FILES = $(wildcard reduce/*)
# mapreduce: $(MAPREDUCE_FILES) $(HTML_FILES)
#	@$(MKFILE_DIR)/reduce.sh $(SOURCE_DIR)

#
# END DYNAMICALLY GENERATED RULES
#######################################################################################################

# Rule to create favicons
# the complex patsubst is needed to extract just the size from the target filename
FAVICON_SOURCE := $(METADATA_DIR)/favicon-source.png
$(BUILD_DIR)/icons/favicon-%: $(FAVICON_SOURCE)
	@mkdir -p $(ICONS_DIR)
	./favicons.sh $< $(patsubst $(ICONS_DIR)/favicon-%.png,%,$@) > $@
$(FAVICON_ICO_TARGET): $(FAVICON_TARGETS)
	magick $(FAVICON_SOURCE) -resize "32x32" $@

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
	@$(MKFILE_DIR)/single.sh $< > $(TMP_FINAL_TARGET)
	@$(shell touch -t $(MAKE_START_TIME) $(TMP_FINAL_TARGET))	
	@mv $(TMP_FINAL_TARGET) $@

# Rule to simply copy all files that aren't otherwise processed. 
# Because the previous rule(s) are more specific, this just gets anything not otherwise specified
$(BUILD_DIR)/%: $(SOURCE_DIR)/%
	@mkdir -p $(dir $@)
	@cp $< $@

# Default target
all: $(ALL_FILE_TARGETS) $(MAPREDUCE_TARGETS) $(FAVICON_TARGETS) $(FAVICON_ICO_TARGET)

#######################################################################################################
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
