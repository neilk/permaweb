#!/usr/bin/env bash

# Record that we ran
basename "$0" >> "$PERMAWEB_SCRIPT_RECORD"

navigation=$(cat << 'EOF'

<header>
    <nav>
        <ul>
            <li class="selected">
                <a href="/">Main</a>
            </li>
            <li>
                <a href="/blog">Blog</a>
            </li>
            <li>
                <a href="/contact">Contact</a>
            </li>
        </ul>
    </nav>
</header>
EOF
)


body_regex="(.*<body.*>)(.*)"

while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" =~ $body_regex ]]; then
    # add an H1
    echo "${BASH_REMATCH[1]}$navigation${BASH_REMATCH[2]}"
  else
    echo "$line"
  fi
done