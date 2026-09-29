#!/bin/bash

curl "${OPENAI_BASE_URL:?set OPENAI_BASE_URL}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${OPENAI_API_KEY:?set OPENAI_API_KEY}" \
  -d '{
    "model": "'"${MODEL:-gpt-4o-mini}"'",
    "stream": true,
    "messages": [
      {
        "role": "user",
        "content": "only say yes"
      }
    ]
  }'
