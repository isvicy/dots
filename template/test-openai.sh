#!/bin/bash

curl "${OPENAI_API_BASE}/chat/completions" \
	-H "Content-Type: application/json" \
	-H "Authorization: Bearer ${OPENAI_API_KEY}" \
	-d '{
    "model": "gpt-3.5-turbo",
    "messages": [
      {
        "role": "user",
        "content": "please only say hello"
      }
    ],
    "temperature": 0.7
  }'
