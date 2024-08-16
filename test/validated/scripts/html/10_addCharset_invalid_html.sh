#!/usr/bin/env bash

sed -E 's|([[:space:]]*)</head>|\1    <meta charset="UTF-8"\n\1</head>|g'