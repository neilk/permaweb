#!/usr/bin/env bash

# Initialize the variable
title_content="Unknown title"
title_regex="<title>(.*)</title>"
body_regex="(.*<body.*>)(.*)"

# Read from stdin line by line
while IFS= read -r line || [[ -n "$line" ]]; do
  # Check if the line contains the <title> tag
  if [[ "$line" =~ $title_regex ]]; then
    # Extract the content between the title tags
    title_content="${BASH_REMATCH[1]}"
  fi
  if [[ "$line" =~ $body_regex ]]; then
    # add an H1
    echo "${BASH_REMATCH[1]}<h1>$title_content<h1>${BASH_REMATCH[2]}"
  else
    echo "$line"
  fi
done