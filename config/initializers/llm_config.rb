# LLM Configuration
# Set these environment variables in your .env file or deployment environment

# Require HTTParty for API calls
require "httparty"

# Ollama Configuration (for local testing)
# USE_OLLAMA=true
# OLLAMA_BASE_URL=http://localhost:11434

# Default to Ollama if no specific configuration is set
Rails.application.config.llm_provider = "ollama"
