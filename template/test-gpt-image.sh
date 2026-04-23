#!/bin/bash
set -euo pipefail

prompt="${1:-a red panda coding on a laptop, studio ghibli style}"
size="${2:-1024x1024}"
out="${3:-/tmp/gpt-image-$(date +%s).png}"
top_model="${TOP_MODEL:-gpt-5.4}"
image_model="${IMAGE_MODEL:-gpt-image-2}"

endpoint="$(pass show work/domains/qianxun-openai)"
api_key="$(pass show work/staff-key)"

response="$(curl -sS "${endpoint}/v1/responses" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${api_key}" \
  -d "$(jq -n \
    --arg model "$top_model" \
    --arg prompt "$prompt" \
    --arg image_model "$image_model" \
    --arg size "$size" \
    '{
       model: $model,
       input: $prompt,
       tools: [{type: "image_generation", model: $image_model, size: $size}]
     }')")"

b64="$(printf '%s' "$response" | jq -r '
  .output[]? | select(.type == "image_generation_call") | .result // empty
' | head -n1)"

if [[ -z "$b64" ]]; then
  echo "no image_generation_call result in response:" >&2
  printf '%s\n' "$response" >&2
  exit 1
fi

printf '%s' "$b64" | base64 -d > "$out"
echo "$out"
