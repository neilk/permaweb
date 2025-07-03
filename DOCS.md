# Permaweb Documentation

A framework for building personal websites designed to last decades with minimal maintenance.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Project Structure](#project-structure)
3. [HTML Transformation Pipeline](#html-transformation-pipeline)
4. [Writing Transformation Scripts](#writing-transformation-scripts)
5. [Map-Reduce for Site-Wide Features](#map-reduce-for-site-wide-features)
6. [Building and Development](#building-and-development)
7. [Advanced Topics](#advanced-topics)
8. [Example Project Walkthrough](#example-project-walkthrough)

## Quick Start

### Prerequisites

You need a Unix-like system (Linux, macOS) with:
- `bash` (available by default)
- `make` (available by default)
- Basic Unix tools (`sed`, `awk`, `find`, etc.)

### Creating Your First Site

1. **Set up directory structure:**
```bash
mkdir my-website
cd my-website
mkdir source scripts build
mkdir scripts/html scripts/validators
```

2. **Create a simple HTML page:**
```bash
cat > source/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
</head>
<body>
    <h1>My Website</h1>
    <p>Welcome to my personal website!</p>
</body>
</html>
EOF
```

3. **Create your first transformation script:**
```bash
cat > scripts/html/10_addCharset.sh << 'EOF'
#!/usr/bin/env bash
sed -E 's|([[:space:]]*)</head>|\1    <meta charset="UTF-8">\n\1</head>|g'
EOF
chmod +x scripts/html/10_addCharset.sh
```

4. **Build your site:**
```bash
# Assuming permaweb is in a parallel directory
../permaweb/single.sh -s scripts source/index.html > build/index.html
```

Your first transformed page will have the charset meta tag automatically added!

## Project Structure

A typical permaweb project follows this structure:

```
my-website/
├── source/                    # Source content
│   ├── index.html            # Main page
│   ├── about/                # Section directories
│   │   └── index.html
│   ├── style.css             # Stylesheets
│   ├── images/               # Static assets
│   └── fonts/
├── scripts/                  # Transformation scripts
│   ├── html/                 # HTML processing scripts
│   │   ├── 10_addCharset.sh  # Numbered for execution order
│   │   ├── 20_addTitle.sh
│   │   ├── 30_addNav.sh
│   │   └── 90_addFooter.sh
│   └── validators/           # Validation scripts
│       └── html              # HTML validator
├── reducers/                 # Map-reduce aggregation
│   └── html/
│       ├── rss.xml/
│       │   ├── map.js
│       │   └── reduce.js
│       └── sitemap.xml/
├── build/                    # Generated output
├── metadata/                 # Build metadata (favicons, etc.)
├── Makefile                  # Build configuration
└── build.sh                 # Build script
```

## HTML Transformation Pipeline

Permaweb processes your HTML through a pipeline of transformation scripts. Each script:
- Reads HTML from stdin
- Writes transformed HTML to stdout  
- Runs in numbered order (10_, 20_, 30_, etc.)
- Fails gracefully (if a script fails, original input is preserved)

### How the Pipeline Works

```bash
source/index.html 
    | 10_addCharset.sh 
    | 20_addTitle.sh 
    | 30_addNavigation.sh 
    | 90_addFooter.sh 
    → build/index.html
```

Each script transformation is cached, so only changed scripts or content trigger re-processing.

### Environment Variables

Scripts have access to these environment variables:

- `PERMAWEB_SOURCE_PATH`: Full path to the source file being processed
- `PERMAWEB_SOURCE_DIR`: Directory containing source files (for map-reduce)
- `PERMAWEB_MAP_RESULTS`: File listing map results (for reduce scripts)

## Writing Transformation Scripts

### Basic Script Template

```bash
#!/usr/bin/env bash
# Description of what this script does

# Optional: validate requirements
set -e

# Process stdin to stdout
sed 's/old/new/g'  # Your transformation logic here
```

### Common Patterns

#### 1. Adding Content to Head Section

```bash
#!/usr/bin/env bash
# Add viewport meta tag

sed -E 's|([[:space:]]*)</head>|\1    <meta name="viewport" content="width=device-width, initial-scale=1">\n\1</head>|g'
```

#### 2. Multi-line Processing with State

```bash
#!/usr/bin/env bash
# Extract title and add H1

title_content="Untitled"
title_regex="<title>(.*)</title>"
body_regex="(.*<body.*>)(.*)"

while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" =~ $title_regex ]]; then
    title_content="${BASH_REMATCH[1]}"
  fi
  if [[ "$line" =~ $body_regex ]]; then
    echo "${BASH_REMATCH[1]}<h1>$title_content</h1>${BASH_REMATCH[2]}"
  else
    echo "$line"
  fi
done
```

#### 3. Cross-File Processing (Navigation)

```bash
#!/usr/bin/env bash
# Add navigation based on sibling files

# Build navigation HTML
nav_html="<nav><ul>"
for file in "$(dirname "$PERMAWEB_SOURCE_PATH")"/*.html; do
  if [[ -f "$file" ]]; then
    title=$(sed -n 's/.*<title>\(.*\)<\/title>.*/\1/p' "$file")
    filename=$(basename "$file")
    if [[ "$file" == "$PERMAWEB_SOURCE_PATH" ]]; then
      nav_html+="<li><strong>$title</strong></li>"
    else
      nav_html+="<li><a href=\"$filename\">$title</a></li>"
    fi
  fi
done
nav_html+="</ul></nav>"

# Insert navigation after opening body tag
sed "s|<body>|<body>$nav_html|"
```

#### 4. Using Template Files

```bash
#!/usr/bin/env bash
# Add header from template

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
header_content=$(cat "${SCRIPT_DIR}/header.html")

sed "s|</head>|$header_content</head>|"
```

### Script Naming Conventions

Use numbered prefixes to control execution order:

- `10_` - Basic setup (charset, viewport)
- `15_` - Styles and meta tags  
- `20_` - Content headers (H1, title extraction)
- `30_` - Navigation elements
- `40_` - Main content processing
- `90_` - Footer and finalization

### Directory-Based Scripts

For complex scripts with multiple files:

```
scripts/html/30_addNavigation/
├── main.sh           # Main executable (required)
├── navigation.html   # Template file
└── README.md         # Documentation
```

Permaweb will execute `main.sh` and include all files in the cache hash.

## Map-Reduce for Site-Wide Features

For features that aggregate data across multiple files (RSS feeds, sitemaps, tag clouds), use the map-reduce pattern.

### Directory Structure

```
reducers/
└── html/                    # Process HTML files
    ├── rss.xml/            # Output filename
    │   ├── map.js          # Extract data from each file
    │   └── reduce.js       # Aggregate into final output
    └── sitemap.xml/
        ├── map.py
        └── reduce.py
```

### Map Script Example

```javascript
#!/usr/bin/env node
// Extract article metadata from HTML

const fs = require('fs');
const path = require('path');

// Read HTML from stdin
let html = '';
process.stdin.on('data', chunk => html += chunk);
process.stdin.on('end', () => {
  // Extract metadata
  const titleMatch = html.match(/<title>(.*?)<\/title>/);
  const dateMatch = html.match(/dc\.date\.created.*?content="([^"]+)"/);
  const descMatch = html.match(/<meta name="description" content="([^"]+)"/);
  
  if (titleMatch && dateMatch) {
    const sourcePath = process.env.PERMAWEB_SOURCE_PATH;
    const url = path.relative(process.env.PERMAWEB_SOURCE_DIR, sourcePath)
                    .replace(/\.html$/, '/')
                    .replace(/\/index\/$/, '/');
    
    // Output JSON for reduce phase
    console.log(JSON.stringify({
      title: titleMatch[1],
      date: dateMatch[1],
      description: descMatch?.[1] || '',
      url: url
    }));
  }
});
```

### Reduce Script Example

```javascript
#!/usr/bin/env node
// Generate RSS feed from article data

let input = '';
process.stdin.on('data', chunk => input += chunk);
process.stdin.on('end', () => {
  const articles = input.trim().split('\n')
    .filter(line => line)
    .map(line => JSON.parse(line))
    .sort((a, b) => new Date(b.date) - new Date(a.date))
    .slice(0, 10); // Latest 10 articles

  // Generate RSS XML
  console.log(`<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>My Blog</title>
    <description>Personal blog and projects</description>
    <link>https://example.com/</link>`);

  articles.forEach(article => {
    console.log(`    <item>
      <title>${escapeXml(article.title)}</title>
      <link>https://example.com${article.url}</link>
      <description>${escapeXml(article.description)}</description>
      <pubDate>${new Date(article.date).toUTCString()}</pubDate>
    </item>`);
  });

  console.log(`  </channel>
</rss>`);
});

function escapeXml(str) {
  return str.replace(/[<>&'"]/g, c => ({
    '<': '&lt;', '>': '&gt;', '&': '&amp;',
    "'": '&apos;', '"': '&quot;'
  })[c]);
}
```

### Running Map-Reduce

```bash
# Process all source files through map-reduce
../permaweb/reduce.sh -s reducers -o build source
```

This will:
1. Run map scripts on each matching source file
2. Aggregate results through reduce scripts  
3. Output final files to build directory
4. Cache all results for fast incremental builds

## Building and Development

### Using the Makefile

Create a `Makefile` to automate your build:

```makefile
# Build all HTML files
html: source/index.html scripts/html/*
	../permaweb/single.sh -s scripts source/index.html > build/index.html

# Run map-reduce for feeds
feeds:
	../permaweb/reduce.sh -s reducers -o build source

# Build everything
all: html feeds

# Development server
serve:
	cd build && python3 -m http.server 8000

# Watch for changes (requires entr)
watch:
	find source scripts reducers -type f | entr -r make all

.PHONY: all html feeds serve watch
```

### Build Script Example

```bash
#!/bin/bash
# build.sh - Main build script

set -e

echo "Building website..."

# Generate dynamic content
./generate_writing_index.js > source/writing/index.html

# Build using permaweb Makefile
make all -f ../permaweb/Makefile

echo "Build complete! Files in build/"
```

### Development Workflow

1. **Edit source files** in `source/`
2. **Test transformations** with single files:
   ```bash
   ../permaweb/single.sh -s scripts source/index.html
   ```
3. **Run full build** with `make all`
4. **Serve locally** for testing:
   ```bash
   cd build && python3 -m http.server 8000
   ```
5. **Use file watching** for live development:
   ```bash
   find source scripts -name '*.html' -o -name '*.sh' | entr -r make all
   ```

## Advanced Topics

### Validation Scripts

Create validators to check your HTML:

```bash
#!/usr/bin/env bash
# scripts/validators/html - HTML validator

tempFile=$(mktemp -q "/tmp/permaweb.XXXX" || exit 1) 
trap 'rm -f -- "$tempFile"' EXIT

# Save input
cat > "$tempFile"

# Validate HTML structure
if ! grep -q '<html' "$tempFile"; then
  echo "ERROR: No <html> tag found" >&2
  exit 1
fi

if ! grep -q '<head>' "$tempFile"; then
  echo "ERROR: No <head> section found" >&2
  exit 1
fi

# Check for required meta tags
if ! grep -q 'charset=' "$tempFile"; then
  echo "WARNING: No charset specified" >&2
fi

echo "HTML validation passed" >&2
exit 0
```

### Error Handling

Scripts should be defensive and handle errors gracefully:

```bash
#!/usr/bin/env bash
set -e  # Exit on error

# Validate input
if ! command -v node >/dev/null 2>&1; then
  echo "ERROR: Node.js not found" >&2
  exit 1
fi

# Use temporary files safely
tempFile=$(mktemp -q "/tmp/permaweb.XXXX" || exit 1)
trap 'rm -f -- "$tempFile"' EXIT

# Process with error checking
if ! process_html < "$tempFile" > output; then
  echo "ERROR: Processing failed" >&2
  exit 1
fi
```

### Performance and Caching

Permaweb automatically caches script results, but you can optimize:

1. **Keep scripts simple** - Complex scripts take longer to hash and execute
2. **Use incremental processing** - Only process what changed
3. **Minimize file I/O** - Use pipes and temporary files efficiently
4. **Profile with time** - Identify slow transformation steps

### Testing Your Scripts

Create tests for your transformation scripts:

```bash
#!/bin/bash
# test_charset.sh - Test charset addition

set -e

# Test input
input='<!DOCTYPE html><html><head></head><body></body></html>'

# Expected output
expected='<!DOCTYPE html><html><head>    <meta charset="UTF-8">
</head><body></body></html>'

# Run transformation
output=$(echo "$input" | ./scripts/html/10_addCharset.sh)

# Compare results
if [ "$output" = "$expected" ]; then
  echo "✓ Charset script test passed"
else
  echo "✗ Charset script test failed"
  echo "Expected: $expected"
  echo "Got: $output"
  exit 1
fi
```

## Example Project Walkthrough

Let's build a complete personal website step by step.

### 1. Project Setup

```bash
mkdir personal-website
cd personal-website
mkdir -p source/{about,work,writing} scripts/html reducers/html build
```

### 2. Create Base HTML Template

```bash
cat > source/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <title>Welcome</title>
</head>
<body>
  <h1>John Doe</h1>
  <p>Software developer and writer.</p>
  
  <h2>Recent Writing</h2>
  <!-- This will be populated by a script -->
  
  <h2>Contact</h2>
  <p>Email: john@example.com</p>
</body>
</html>
EOF
```

### 3. Essential Transformation Scripts

**Add charset and viewport:**
```bash
cat > scripts/html/10_addMeta.sh << 'EOF'
#!/usr/bin/env bash
sed -E 's|([[:space:]]*)</head>|\1    <meta charset="UTF-8">\n\1    <meta name="viewport" content="width=device-width, initial-scale=1">\n\1</head>|g'
EOF
chmod +x scripts/html/10_addMeta.sh
```

**Add CSS:**
```bash
cat > scripts/html/15_addStyle.sh << 'EOF'
#!/usr/bin/env bash
sed -E 's|([[:space:]]*)</head>|\1    <link rel="stylesheet" href="/style.css">\n\1</head>|g'
EOF
chmod +x scripts/html/15_addStyle.sh
```

**Add navigation:**
```bash
cat > scripts/html/30_addNav.sh << 'EOF'
#!/usr/bin/env bash

# Create navigation menu
nav_html='<nav><ul>'
nav_html+='<li><a href="/">Home</a></li>'
nav_html+='<li><a href="/about/">About</a></li>'
nav_html+='<li><a href="/work/">Work</a></li>'
nav_html+='<li><a href="/writing/">Writing</a></li>'
nav_html+='</ul></nav>'

# Insert after opening body tag
sed "s|<body>|<body>$nav_html|"
EOF
chmod +x scripts/html/30_addNav.sh
```

### 4. Create Additional Pages

```bash
# About page
cat > source/about/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <title>About</title>
</head>
<body>
  <h1>About John Doe</h1>
  <p>I'm a software developer with 10 years of experience...</p>
</body>
</html>
EOF

# Work page  
cat > source/work/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <title>Work</title>
</head>
<body>
  <h1>My Work</h1>
  <h2>Projects</h2>
  <ul>
    <li><strong>Project One</strong> - Description of project</li>
    <li><strong>Project Two</strong> - Another project</li>
  </ul>
</body>
</html>
EOF
```

### 5. Add RSS Feed with Map-Reduce

**Create map script to extract article metadata:**
```bash
mkdir -p reducers/html/rss.xml
cat > reducers/html/rss.xml/map.sh << 'EOF'
#!/usr/bin/env bash

# Only process files in writing directory
if [[ ! "$PERMAWEB_SOURCE_PATH" =~ /writing/ ]]; then
  exit 0
fi

# Extract title and date
title=$(sed -n 's/.*<title>\(.*\)<\/title>.*/\1/p')
url=$(basename "$(dirname "$PERMAWEB_SOURCE_PATH")")

# Output metadata (in this simple example, just the title)
echo "$title|$url"
EOF
chmod +x reducers/html/rss.xml/map.sh
```

**Create reduce script to generate RSS:**
```bash
cat > reducers/html/rss.xml/reduce.sh << 'EOF'
#!/usr/bin/env bash

echo '<?xml version="1.0" encoding="UTF-8"?>'
echo '<rss version="2.0">'
echo '  <channel>'
echo '    <title>John Doe - Writing</title>'
echo '    <description>Personal blog</description>'
echo '    <link>https://johndoe.com/</link>'

# Process each article
while IFS='|' read -r title url; do
  if [[ -n "$title" && -n "$url" ]]; then
    echo "    <item>"
    echo "      <title>$title</title>"
    echo "      <link>https://johndoe.com/writing/$url/</link>"
    echo "    </item>"
  fi
done

echo '  </channel>'
echo '</rss>'
EOF
chmod +x reducers/html/rss.xml/reduce.sh
```

### 6. Create Build System

```bash
cat > build.sh << 'EOF'
#!/bin/bash
set -e

echo "Building personal website..."

# Copy static assets
cp source/style.css build/ 2>/dev/null || true

# Build HTML files using permaweb
find source -name "*.html" | while read -r file; do
  # Get relative path
  rel_path=${file#source/}
  output_file="build/$rel_path"
  
  # Create output directory
  mkdir -p "$(dirname "$output_file")"
  
  # Transform HTML
  ../permaweb/single.sh -s scripts "$file" > "$output_file"
  echo "Built $output_file"
done

# Generate RSS feed
../permaweb/reduce.sh -s reducers -o build source

echo "Website built successfully in build/"
EOF
chmod +x build.sh
```

### 7. Add Basic Styling

```bash
cat > source/style.css << 'EOF'
/* Basic styling for personal website */
body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  line-height: 1.6;
  max-width: 800px;
  margin: 0 auto;
  padding: 20px;
  color: #333;
}

nav ul {
  list-style: none;
  padding: 0;
  display: flex;
  gap: 20px;
  border-bottom: 1px solid #eee;
  padding-bottom: 10px;
  margin-bottom: 30px;
}

nav a {
  text-decoration: none;
  color: #0066cc;
}

nav a:hover {
  text-decoration: underline;
}

h1 {
  color: #2c3e50;
  border-bottom: 2px solid #3498db;
  padding-bottom: 10px;
}

h2 {
  color: #34495e;
  margin-top: 30px;
}

code {
  background: #f4f4f4;
  padding: 2px 4px;
  border-radius: 3px;
  font-family: 'Monaco', 'Menlo', monospace;
}
EOF
```

### 8. Build and Test

```bash
# Build the site
./build.sh

# Serve locally for testing
cd build
python3 -m http.server 8000
# Visit http://localhost:8000
```

### 9. Development Workflow

```bash
# Watch for changes and rebuild automatically
find source scripts reducers -type f | entr -r ./build.sh
```

This creates a complete personal website with:
- ✅ Multi-page navigation
- ✅ Consistent styling and meta tags
- ✅ RSS feed generation
- ✅ Automated build process
- ✅ Development server
- ✅ File watching for live development

You can extend this foundation by adding more transformation scripts, additional map-reduce features (sitemap, tag cloud), or enhanced styling and JavaScript functionality.

## Next Steps

1. **Add more transformation scripts** for enhanced functionality
2. **Implement caching** for faster rebuilds during development  
3. **Create deployment scripts** to publish your site
4. **Add content management tools** like automated article indexing
5. **Implement advanced features** like search, comments, or analytics

The beauty of permaweb is that each enhancement is optional and independent - if any part breaks in the future, your core website continues to work perfectly.