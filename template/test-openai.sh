#!/bin/bash

curl "${OPENAI_API_BASE}/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${OPENAI_API_KEY}" \
  -d '{
    "model": "gpt-4.1",
    "stream": true,
    "messages": [
      {
        "role": "user",
        "content": "only say yes"
      }
    ]
  }'
