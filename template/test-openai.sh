#!/bin/bash

curl "https://api.$(pass show work/domain-base)/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(pass show work/staff-key)" \
  -d '{
    "model": "opensource-gpt-oss-20b-chat",
    "stream": true,
    "messages": [
      {
        "role": "user",
        "content": "only say yes"
      }
    ]
  }'
