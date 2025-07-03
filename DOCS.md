# Permaweb Documentation

A framework for building simple static websites, designed to last decades with minimal maintenance.

## WARNING

This documentation was mostly written by an LLM, with some human supervision, and may have serious errors.


## Table of Contents

1. [Quick Start](#quick-start)
2. [Philosophy: Rigid Structure, Flexible Tools](#philosophy-rigid-structure-flexible-tools)
3. [Project Structure](#project-structure)
4. [HTML Transformation Pipeline](#html-transformation-pipeline)
5. [Writing Transformation Scripts](#writing-transformation-scripts)
6. [Map-Reduce for Site-Wide Features](#map-reduce-for-site-wide-features)
7. [Building and Development](#building-and-development)
8. [Advanced Topics](#advanced-topics)
9. [Example Project Walkthrough](#example-project-walkthrough)

## Quick Start

### Prerequisites

You need a Unix-like system (Linux, macOS) with:

- `bash` and `make` (available by default on all Unix systems)
- Any programming language you prefer (Python, Node.js, Rust, Go, etc.)

**That's it!** Permaweb's core is intentionally primitive for longevity, but your scripts can use any modern tools.

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

3. **Create your first transformation script (using Python):**

```python
#!/usr/bin/env python3
# scripts/html/10_addCharset.py
import sys
import re

html = sys.stdin.read()
# Add charset meta tag before closing head
html = re.sub(r'(\s*)</head>', r'\1    <meta charset="UTF-8">\n\1</head>', html)
print(html, end='')
```

```bash
chmod +x scripts/html/10_addCharset.py
```

4. **Create a build script:**

```bash
cat > build.sh << 'EOF'
#!/bin/bash
# Build script using permaweb's Makefile
# TODO: This is a bit of a wart - the Makefile makes assumptions about structure
# In the future we may generate custom Makefiles for each project

# Assuming permaweb is in a parallel directory
gmake all -f ../path/to/permaweb/Makefile
EOF
chmod +x build.sh
```

5. **Build your site:**

```bash
./build.sh
```
Check out the `build/` directory. 

Your first transformed page will have the charset meta tag automatically added!

6. **Publishing your site:**

That is up to you. `permaweb` is very compatible with simply sync'ing the build directory to someplace in the cloud.


## Philosophy: Rigid Structure, Flexible Tools

Permaweb embodies a key principle: **rigid directory structure, completely flexible tooling**.

### The Framework is Primitive (By Design)

Permaweb's core (`single.sh`, `reduce.sh`, `lib.sh`) is written in basic bash and uses only standard Unix tools. This isn't a limitation—it's intentional. These tools have existed for decades and will likely exist for decades more.

### Your Scripts Use Whatever You Want

Your transformation scripts can be written in any language, as long as they follow these conventions

1. **Follow directory naming conventions** (covered below)
2. **Scripts read from stdin, write to stdout**
3. **Scripts are executable**
4. **Return appropriate exit codes** (0 = success, non-zero = failure)

Everything else is up to you!

### Real-World Examples

Here's how you might organize scripts using different languages, with an intentionally eclectic set of scripts.

```text
scripts/html/
├── 10_addMeta.py          # Python with Beautiful Soup
├── 20_extractTitle.js     # Node.js with Cheerio  
├── 22_addNav.rs           # Rust for performance
├── 40_processImages.go    # Go for image processing
├── 51_addFooter.rb        # Ruby for text processing
└── 90_minify.php          # PHP for final optimization
```

All of these are designed to run _in order_. Imagine we are processing `home.html`

1. The contents of `source/home.html` are piped into `10_addMeta.py`, which reads HTML, then adds some metadata to the HTML, and prints the HTML.
2. ... that HTML is read by `20_extractTitle.js`, which reads in HTML, reads what's in the `<title>` tags and applies it into the `<h1>` tag, if there isn't one already. Then it prints out the resulting HTML.
3. ... and _that_ HTML is read by 22_addNav.rs, which slams in some navigation. The addNav script examines some of the environment variables, such as `$PERMAWEB_SOURCE_FILE` to alter the navigation (you might want the navigation item for the current page highlighted somehow). Then _that_ prints some HTML.
4. ... and _that_ HTML is read by `40_processImages.go`. Unfortunately, something is broken about this script. Maybe it was expecting at least one image tag in the HTML, and this source does not have one. Or maybe Go itself is somehow broken. So, at this stage, we return a non-zero error code, like a good Unix program should.  At this point, having detected an error, the permaweb framework _skips over_ 40_processImages.go, and feeds the output from the previous step - `22_addNav.rs` - to the next step.
5. ... the HTML from the previous step is now passed to `51_addFooter.rb`, which adds a standard footer to the page, and emits that transformed HTML.
6. ... penultimately, the full page with headers, navigation, and footer, is passed to a minification script, `90_minify.php`, which again outputs HTML.
7. ... and then those contents are deposited in `build/home.html`.





### Dependencies and Installation

Each language can use its own package management. That's your problem.

The only requirement is that your scripts are executable and follow the stdin→stdout pattern.

## Project Structure

A typical permaweb project follows this structure:

```text
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
│   │   ├── 10_addCharset.py  # Python, Node.js, Rust, etc.
│   │   ├── 20_addTitle.js    # Use whatever language you want
│   │   ├── 30_addNav.rs      # Mix and match freely
│   │   └── 90_addFooter.go
│   └── validators/           # Validation scripts
│       └── html              # HTML validator (any language)
├── reducers/                 # Map-reduce aggregation
│   └── html/
│       ├── rss.xml/
│       │   ├── map.py        # Python for data extraction
│       │   └── reduce.js     # Node.js for XML generation
│       └── sitemap.xml/
│           ├── map.rs        # Rust for performance
│           └── reduce.py     # Python for XML templating
├── build/                    # Generated output
├── metadata/                 # Build metadata (favicons, etc.)
├── package.json              # Node.js dependencies (optional)
├── requirements.txt          # Python dependencies (optional)
├── Cargo.toml               # Rust dependencies (optional)
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

**Python Example:**

```python
#!/usr/bin/env python3
"""Description of what this script does"""
import sys
import re

def transform_html(html):
    # Your transformation logic here
    return html.replace('old', 'new')

if __name__ == '__main__':
    html = sys.stdin.read()
    result = transform_html(html)
    print(result, end='')
```

**Node.js Example:**

```javascript
#!/usr/bin/env node
// Description of what this script does

const fs = require('fs');

let html = '';
process.stdin.on('data', chunk => html += chunk);
process.stdin.on('end', () => {
    // Your transformation logic here
    const result = html.replace(/old/g, 'new');
    process.stdout.write(result);
});
```

### Common Patterns

#### 1. Adding Content to Head Section

**Python with Beautiful Soup:**

```python
#!/usr/bin/env python3
"""Add viewport meta tag"""
import sys
from bs4 import BeautifulSoup

html = sys.stdin.read()
soup = BeautifulSoup(html, 'html.parser')

# Create viewport meta tag
viewport_tag = soup.new_tag('meta', attrs={
    'name': 'viewport', 
    'content': 'width=device-width, initial-scale=1'
})

# Add to head
if soup.head:
    soup.head.append(viewport_tag)

print(soup.prettify(), end='')
```

**Node.js with Cheerio:**

```javascript
#!/usr/bin/env node
const cheerio = require('cheerio');

let html = '';
process.stdin.on('data', chunk => html += chunk);
process.stdin.on('end', () => {
    const $ = cheerio.load(html);
    
    // Add viewport meta tag
    $('head').append('<meta name="viewport" content="width=device-width, initial-scale=1">');
    
    process.stdout.write($.html());
});
```

#### 2. Multi-line Processing with State

**Python Example:**

```python
#!/usr/bin/env python3
"""Extract title and add H1"""
import sys
import re

html = sys.stdin.read()

# Extract title
title_match = re.search(r'<title>(.*?)</title>', html)
title = title_match.group(1) if title_match else 'Untitled'

# Add H1 after opening body tag
html = re.sub(
    r'(<body[^>]*>)', 
    rf'\1<h1>{title}</h1>', 
    html
)

print(html, end='')
```

**Rust Example:**

```rust
#!/usr/bin/env -S cargo +nightly -Zscript
//! ```cargo
//! [dependencies]
//! regex = "1.0"
//! ```

use regex::Regex;
use std::io::{self, Read};

fn main() -> io::Result<()> {
    let mut html = String::new();
    io::stdin().read_to_string(&mut html)?;
    
    // Extract title
    let title_re = Regex::new(r"<title>(.*?)</title>").unwrap();
    let title = title_re
        .captures(&html)
        .and_then(|caps| caps.get(1))
        .map(|m| m.as_str())
        .unwrap_or("Untitled");
    
    // Add H1 after opening body tag
    let body_re = Regex::new(r"(<body[^>]*>)").unwrap();
    let result = body_re.replace(&html, |caps: &regex::Captures| {
        format!("{}<h1>{}</h1>", &caps[1], title)
    });
    
    print!("{}", result);
    Ok(())
}
```

#### 3. Cross-File Processing (Navigation)

**Python Example:**

```python
#!/usr/bin/env python3
"""Add navigation based on sibling files"""
import sys
import os
import re
from pathlib import Path

def extract_title(file_path):
    """Extract title from HTML file"""
    try:
        with open(file_path, 'r') as f:
            content = f.read()
            match = re.search(r'<title>(.*?)</title>', content)
            return match.group(1) if match else 'Untitled'
    except:
        return 'Untitled'

def build_navigation():
    """Build navigation from sibling files"""
    source_path = os.environ.get('PERMAWEB_SOURCE_PATH')
    if not source_path:
        return '<nav></nav>'
    
    source_dir = Path(source_path).parent
    current_file = Path(source_path).name
    
    nav_items = []
    for html_file in source_dir.glob('*.html'):
        title = extract_title(html_file)
        filename = html_file.name
        
        if filename == current_file:
            nav_items.append(f'<li><strong>{title}</strong></li>')
        else:
            nav_items.append(f'<li><a href="{filename}">{title}</a></li>')
    
    return f'<nav><ul>{"".join(nav_items)}</ul></nav>'

if __name__ == '__main__':
    html = sys.stdin.read()
    navigation = build_navigation()
    
    # Insert navigation after opening body tag
    result = re.sub(r'(<body[^>]*>)', rf'\1{navigation}', html)
    print(result, end='')
```

#### 4. Using Template Files

**Node.js Example:**

```javascript
#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

// Get script directory
const scriptDir = path.dirname(process.argv[1]);
const headerPath = path.join(scriptDir, 'header.html');

let html = '';
process.stdin.on('data', chunk => html += chunk);
process.stdin.on('end', () => {
    try {
        const headerContent = fs.readFileSync(headerPath, 'utf8');
        const result = html.replace('</head>', headerContent + '</head>');
        process.stdout.write(result);
    } catch (err) {
        // If template file doesn't exist, pass through unchanged
        process.stdout.write(html);
    }
});
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

**Node.js for Metadata Extraction:**

```javascript
#!/usr/bin/env node
// Extract article metadata from HTML

const fs = require('fs');
const path = require('path');
const cheerio = require('cheerio');

// Read HTML from stdin
let html = '';
process.stdin.on('data', chunk => html += chunk);
process.stdin.on('end', () => {
  const $ = cheerio.load(html);
  
  const title = $('title').text();
  const date = $('meta[name="dc.date.created"]').attr('content') || 
               $('meta[property="article:published_time"]').attr('content');
  const description = $('meta[name="description"]').attr('content') || '';
  
  if (title && date) {
    const sourcePath = process.env.PERMAWEB_SOURCE_PATH;
    const sourceDir = process.env.PERMAWEB_SOURCE_DIR;
    const url = path.relative(sourceDir, sourcePath)
                    .replace(/\.html$/, '/')
                    .replace(/\/index\/$/, '/');
    
    // Output JSON for reduce phase
    console.log(JSON.stringify({
      title,
      date,
      description,
      url: '/' + url
    }));
  }
});
```

**Python Alternative:**

```python
#!/usr/bin/env python3
"""Extract article metadata from HTML"""
import sys
import json
import os
import re
from pathlib import Path
from bs4 import BeautifulSoup

html = sys.stdin.read()
soup = BeautifulSoup(html, 'html.parser')

# Extract metadata
title_tag = soup.find('title')
date_meta = soup.find('meta', attrs={'name': 'dc.date.created'}) or \
           soup.find('meta', attrs={'property': 'article:published_time'})
desc_meta = soup.find('meta', attrs={'name': 'description'})

title = title_tag.get_text() if title_tag else None
date = date_meta.get('content') if date_meta else None
description = desc_meta.get('content') if desc_meta else ''

if title and date:
    source_path = os.environ.get('PERMAWEB_SOURCE_PATH', '')
    source_dir = os.environ.get('PERMAWEB_SOURCE_DIR', '')
    
    rel_path = Path(source_path).relative_to(source_dir)
    url = '/' + str(rel_path).replace('.html', '/').replace('/index/', '/')
    
    # Output JSON for reduce phase
    print(json.dumps({
        'title': title,
        'date': date,
        'description': description,
        'url': url
    }))
```

### Reduce Script Example

**Python for RSS Generation:**

```python
#!/usr/bin/env python3
"""Generate RSS feed from article data"""
import sys
import json
from datetime import datetime
import html

def escape_xml(text):
    """Escape XML special characters"""
    return html.escape(text)

def format_rfc822(date_str):
    """Convert ISO date to RFC 822 format"""
    try:
        dt = datetime.fromisoformat(date_str.replace('Z', '+00:00'))
        return dt.strftime('%a, %d %b %Y %H:%M:%S %z')
    except:
        return date_str

# Read all article data
articles = []
for line in sys.stdin:
    line = line.strip()
    if line:
        try:
            articles.append(json.loads(line))
        except json.JSONDecodeError:
            continue

# Sort by date (newest first) and take latest 10
articles.sort(key=lambda x: x['date'], reverse=True)
articles = articles[:10]

# Generate RSS XML
print('<?xml version="1.0" encoding="UTF-8"?>')
print('<rss version="2.0">')
print('  <channel>')
print('    <title>My Blog</title>')
print('    <description>Personal blog and projects</description>')
print('    <link>https://example.com/</link>')
print('    <language>en-us</language>')

for article in articles:
    title = escape_xml(article['title'])
    description = escape_xml(article['description'])
    url = f"https://example.com{article['url']}"
    pub_date = format_rfc822(article['date'])
    
    print(f'    <item>')
    print(f'      <title>{title}</title>')
    print(f'      <link>{url}</link>')
    print(f'      <description>{description}</description>')
    print(f'      <pubDate>{pub_date}</pubDate>')
    print(f'      <guid>{url}</guid>')
    print(f'    </item>')

print('  </channel>')
print('</rss>')
```

**Rust Alternative for Performance:**

```rust
#!/usr/bin/env -S cargo +nightly -Zscript
//! ```cargo
//! [dependencies]
//! serde = { version = "1.0", features = ["derive"] }
//! serde_json = "1.0"
//! chrono = { version = "0.4", features = ["serde"] }
//! ```

use serde::{Deserialize, Serialize};
use std::io::{self, BufRead};

#[derive(Deserialize, Serialize)]
struct Article {
    title: String,
    date: String,
    description: String,
    url: String,
}

fn escape_xml(s: &str) -> String {
    s.replace('&', "&amp;")
     .replace('<', "&lt;")
     .replace('>', "&gt;")
     .replace('"', "&quot;")
     .replace('\'', "&apos;")
}

fn main() -> io::Result<()> {
    let stdin = io::stdin();
    let mut articles: Vec<Article> = Vec::new();
    
    // Read all articles
    for line in stdin.lock().lines() {
        let line = line?;
        if let Ok(article) = serde_json::from_str::<Article>(&line) {
            articles.push(article);
        }
    }
    
    // Sort by date (newest first) and take latest 10
    articles.sort_by(|a, b| b.date.cmp(&a.date));
    articles.truncate(10);
    
    // Generate RSS
    println!("<?xml version=\"1.0\" encoding=\"UTF-8\"?>");
    println!("<rss version=\"2.0\">");
    println!("  <channel>");
    println!("    <title>My Blog</title>");
    println!("    <description>Personal blog and projects</description>");
    println!("    <link>https://example.com/</link>");
    
    for article in articles {
        println!("    <item>");
        println!("      <title>{}</title>", escape_xml(&article.title));
        println!("      <link>https://example.com{}</link>", article.url);
        println!("      <description>{}</description>", escape_xml(&article.description));
        println!("      <pubDate>{}</pubDate>", article.date);
        println!("    </item>");
    }
    
    println!("  </channel>");
    println!("</rss>");
    
    Ok(())
}
```

### Running Map-Reduce

Map-reduce processing is handled automatically by permaweb's Makefile when you run:

```bash
./build.sh  # Uses gmake all -f ../permaweb/Makefile
```

This will:

1. Run map scripts on each matching source file
2. Aggregate results through reduce scripts  
3. Output final files to build directory
4. Cache all results for fast incremental builds

## Building and Development

### Using Permaweb's Makefile

**Important**: You should use permaweb's built-in Makefile rather than creating your own transformation logic. Currently this requires a somewhat awkward invocation:

```bash
# Build everything using permaweb's Makefile
gmake all -f ../permaweb/Makefile
```

**TODO**: This is admittedly a wart in the current system. The Makefile makes assumptions about your project structure and relative paths. Future versions may:

- Generate custom Makefiles for each project
- Provide a simpler CLI interface
- Auto-detect permaweb location

### Recommended Build Script

Create a `build.sh` script to wrap the Makefile invocation:

```bash
#!/bin/bash
set -e

echo "Building website with permaweb..."

# Build HTML files and run map-reduce
gmake all -f ../permaweb/Makefile

# Optional: copy additional static files
# cp -r source/images build/ 2>/dev/null || true
# cp source/*.css build/ 2>/dev/null || true

echo "Build complete!"
```

### Development Workflow

```bash
# Make build script executable
chmod +x build.sh

# Build your site
./build.sh

# Serve locally for development
cd build && python3 -m http.server 8000

# Watch for changes (in another terminal)
find source scripts reducers -type f | entr -r ./build.sh
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
2. **Test transformations** with build script:
   ```bash
   ./build.sh
   ```
3. **Run full build** with `./build.sh`
4. **Serve locally** for testing:
   ```bash
   cd build && python3 -m http.server 8000
   ```
5. **Use file watching** for live development:
   ```bash
   find source scripts -name '*.html' -o -name '*.py' -o -name '*.js' | entr -r ./build.sh
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

**Add charset and viewport (Python):**

```bash
cat > scripts/html/10_addMeta.py << 'EOF'
#!/usr/bin/env python3
"""Add essential meta tags"""
import sys
import re

html = sys.stdin.read()

# Add charset and viewport meta tags
meta_tags = '''    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">'''

html = re.sub(r'(\s*)</head>', rf'\1{meta_tags}\n\1</head>', html)
print(html, end='')
EOF
chmod +x scripts/html/10_addMeta.py
```

**Add CSS (Node.js):**

```bash
cat > scripts/html/15_addStyle.js << 'EOF'
#!/usr/bin/env node
// Add CSS stylesheet link

let html = '';
process.stdin.on('data', chunk => html += chunk);
process.stdin.on('end', () => {
    const result = html.replace(
        /(\s*)<\/head>/,
        '$1    <link rel="stylesheet" href="/style.css">\n$1</head>'
    );
    process.stdout.write(result);
});
EOF
chmod +x scripts/html/15_addStyle.js
```

**Add navigation (Python):**

```bash
cat > scripts/html/30_addNav.py << 'EOF'
#!/usr/bin/env python3
"""Add site navigation"""
import sys
import re

html = sys.stdin.read()

# Create navigation menu
nav_html = '''<nav>
    <ul>
        <li><a href="/">Home</a></li>
        <li><a href="/about/">About</a></li>
        <li><a href="/work/">Work</a></li>
        <li><a href="/writing/">Writing</a></li>
    </ul>
</nav>'''

# Insert after opening body tag
html = re.sub(r'(<body[^>]*>)', rf'\1{nav_html}', html)
print(html, end='')
EOF
chmod +x scripts/html/30_addNav.py
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

**Create map script to extract article metadata (Python):**

```bash
mkdir -p reducers/html/rss.xml
cat > reducers/html/rss.xml/map.py << 'EOF'
#!/usr/bin/env python3
"""Extract article metadata for RSS feed"""
import sys
import json
import os
from pathlib import Path
from bs4 import BeautifulSoup

# Only process files in writing directory
source_path = os.environ.get('PERMAWEB_SOURCE_PATH', '')
if '/writing/' not in source_path:
    sys.exit(0)

html = sys.stdin.read()
soup = BeautifulSoup(html, 'html.parser')

# Extract metadata
title_tag = soup.find('title')
date_meta = soup.find('meta', attrs={'name': 'dc.date.created'})

if title_tag and date_meta:
    title = title_tag.get_text()
    date = date_meta.get('content')
    
    # Generate URL from file path
    path = Path(source_path)
    url_parts = path.parts
    if 'writing' in url_parts:
        writing_index = url_parts.index('writing')
        if writing_index + 1 < len(url_parts):
            article_slug = url_parts[writing_index + 1]
            url = f"/writing/{article_slug}/"
            
            # Output JSON for reduce phase
            print(json.dumps({
                'title': title,
                'date': date,
                'url': url
            }))
EOF
chmod +x reducers/html/rss.xml/map.py
```

**Create reduce script to generate RSS (Node.js):**

```bash
cat > reducers/html/rss.xml/reduce.js << 'EOF'
#!/usr/bin/env node
// Generate RSS feed from article metadata

const articles = [];

// Read all article data
let input = '';
process.stdin.on('data', chunk => input += chunk);
process.stdin.on('end', () => {
    const lines = input.trim().split('\n').filter(line => line);
    
    for (const line of lines) {
        try {
            articles.push(JSON.parse(line));
        } catch (e) {
            // Skip invalid JSON lines
        }
    }
    
    // Sort by date (newest first)
    articles.sort((a, b) => new Date(b.date) - new Date(a.date));
    
    // Generate RSS XML
    console.log('<?xml version="1.0" encoding="UTF-8"?>');
    console.log('<rss version="2.0">');
    console.log('  <channel>');
    console.log('    <title>John Doe - Writing</title>');
    console.log('    <description>Personal blog</description>');
    console.log('    <link>https://johndoe.com/</link>');
    console.log('    <language>en-us</language>');
    
    for (const article of articles.slice(0, 10)) { // Latest 10
        const title = article.title.replace(/&/g, '&amp;').replace(/</g, '&lt;');
        const url = `https://johndoe.com${article.url}`;
        const date = new Date(article.date).toUTCString();
        
        console.log('    <item>');
        console.log(`      <title>${title}</title>`);
        console.log(`      <link>${url}</link>`);
        console.log(`      <pubDate>${date}</pubDate>`);
        console.log(`      <guid>${url}</guid>`);
        console.log('    </item>');
    }
    
    console.log('  </channel>');
    console.log('</rss>');
});
EOF
chmod +x reducers/html/rss.xml/reduce.js
```

### 6. Create Build System

```bash
cat > build.sh << 'EOF'
#!/bin/bash
set -e

echo "Building personal website..."

# Use permaweb's Makefile for HTML transformation and map-reduce
# TODO: This path assumption is a current limitation of permaweb
gmake all -f ../permaweb/Makefile

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