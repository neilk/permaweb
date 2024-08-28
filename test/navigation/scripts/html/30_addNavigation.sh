#!/usr/bin/env bash

# For each html file in source, obtain the contents of the title tag
# and add it to the navigation bar

# echo "SOURCE: $PERMAWEB_SOURCE_PATH" >&2

# how to cache this
# we need the entire contents of all siblings, and then the contents of the current file
# that is the key to the cache and then the value is the navigation bar
# but can we even save any time here?? we would have to calculate the "directory hash" every time
# unless we can cache the directory hash itself, on the assumption it doesn't change during a run.
# this is not the same as the regular cache, because that persists in between runs.
# alternatively, we could cache the raw nav bar itself, but not the highlighted entry.

ul=$'            <ul>\n'
for file in "$(dirname "$PERMAWEB_SOURCE_PATH")"/*.html; do
  title=$(sed -n 's/.*<title>\(.*\)<\/title>.*/\1/p' "$file")
  trimmedTitle=$(echo "$title" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  anchor="<a href=\"$(basename "$file")\">$trimmedTitle</a>"
  if [[ "$file" == "$PERMAWEB_SOURCE_PATH" ]]; then
    anchor="<strong>$anchor</strong>"
  fi
  ul+="              <li>$anchor</li>"
  ul+=$'\n'
done
ul+=$'            </ul>'

navigation=$(cat << EOF

    <header>
        <nav>
${ul}
        </nav>
    </header>
EOF
)


body_regex="(.*<body.*>)(.*)"

while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" =~ $body_regex ]]; then
    # add navigation
    echo "${BASH_REMATCH[1]}$navigation${BASH_REMATCH[2]}"
  else
    echo "$line"
  fi
done