#!/usr/bin/env bash

curl -X POST "${DIFY_API_BASE}/v1/chat-messages" \
	--header "Authorization: Bearer ${DIFY_API_KEY}" \
	--header 'Content-Type: application/json' \
	--data-raw '{
    "inputs": {},
    "query": "请告诉我你都能做什么",
    "response_mode": "streaming",
    "conversation_id": "",
    "user": "abc-123"
}'
