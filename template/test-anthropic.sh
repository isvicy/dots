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
  --data \
  '{
    "model": "claude-3-5-sonnet-20241022",
    "max_tokens": 100,
    "messages": [
        {"role": "user", "content": "say hello."}
    ]
}'
