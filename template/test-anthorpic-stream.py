import anthropic
from anthropic import Anthropic
import os

# Initialize the client with your API key
client = Anthropic(
    api_key=os.environ["ANTHROPIC_API_KEY"], base_url=os.environ["ANTHROPIC_API_BASE"]
)  # Replace with your actual API key
# Alternative: Use environment variable
# client = Anthropic(api_key=os.environ.get("ANTHROPIC_API_KEY"))

# Create a streaming request
with client.messages.stream(
    model="claude-3-7-sonnet-20250219",
    max_tokens=1024,
    system="You are a helpful AI assistant that provides concise responses.",
    messages=[
        {"role": "user", "content": "Explain quantum computing in simple terms."}
    ],
) as stream:
    # Process the streaming response
    for text in stream.text_stream:
        # In a real application, you might want to print without newlines
        # and flush to create a smooth typing effect
        print(text, end="", flush=True)

    # If you need the complete final message
    print("\n\nFull response:")
    print(stream.get_final_message().content)
