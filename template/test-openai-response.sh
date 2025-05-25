#!/bin/bash

curl "${OPENAI_API_BASE}/responses" \
	-H "Content-Type: application/json" \
	-H "Authorization: Bearer $OPENAI_API_KEY" \
	-d '{
    "model": "gpt-4.1",
    "stream": true,
    "input": "only say yes"
  }'
