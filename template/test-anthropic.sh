#!/bin/bash

# Check if the API key is set
if [ -z "$ANTHROPIC_API_KEY" ]; then
  echo "Error: ANTHROPIC_API_KEY environment variable is not set."
  exit 1
fi

# Check if the API key is set
if [ -z "$ANTHROPIC_API_BASE" ]; then
  echo "Error: ANTHROPIC_API_BASE environment variable is not set."
  exit 1
fi

curl "${ANTHROPIC_API_BASE}/v1/messages" \
  --header "x-api-key: $ANTHROPIC_API_KEY" \
  --header "anthropic-version: 2023-06-01" \
  --header "content-type: application/json" \
  --header "anthropic-beta: prompt-caching-2024-07-31" \
  --data \
  '{
    "model": "claude-3-7-sonnet-20250219",
    "max_tokens": 100,
    "messages": [
        {"role": "user", "content": "only say yes"}
    ]
}'
