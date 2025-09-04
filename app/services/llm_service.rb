class LlmService
  include HTTParty

  def initialize
    @openrouter_api_key = ENV["OPENROUTER_API_KEY"]
    @ollama_base_url = ENV["OLLAMA_BASE_URL"] || "http://localhost:11434"
    @use_ollama = ENV["USE_OLLAMA"] == "false" ? false : true
  end

  def analyze_search_query(query, available_sections = [])
    if @use_ollama
      begin
        result = analyze_with_ollama(query, available_sections)
        if result[:error]
          Rails.logger.error "Ollama analysis failed: #{result[:error]}"
          fallback_analysis(query, available_sections)
        else
          result
        end
      rescue => e
        Rails.logger.error "Ollama analysis exception: #{e.message}"
        fallback_analysis(query, available_sections)
      end
    else
      analyze_with_openrouter(query, available_sections)
    end
  end

  private

  def analyze_with_ollama(query, available_sections)
    prompt = build_prompt(query, available_sections)

    response = self.class.post(
      "#{@ollama_base_url}/api/chat",
      headers: { "Content-Type" => "application/json" },
      body: {
        model: "gpt-oss:20b",
        messages: [
          {
            role: "user",
            content: prompt
          }
        ],
        stream: false,
        options: {
          temperature: 0.1,
          num_predict: 500
        }
      }.to_json,
      timeout: 120
    )

    if response.success?
      content = response.parsed_response["message"]["content"]
      parse_llm_response(content)
    else
      { error: "Ollama API error: #{response.code}" }
    end
  rescue => e
    { error: "Ollama API error: #{e.message}" }
  end

  def build_prompt(query, available_sections)
    sections_text = available_sections.map { |s| "- #{s['title']}" }.join("\n")

    <<~PROMPT
      Analyze this search query and determine if the user is looking for a specific section in the table of contents or if they are asking a general question.

      Query: "#{query}"

      Available sections in the document:
      #{sections_text}

      Please respond ONLY in the following JSON format (no additional text):
      {
        "is_section_search": true/false,
        "target_section": "exact section title if found, or null",
        "confidence": 0.0-1.0,
        "reasoning": "brief explanation of your decision",
        "llm_response": "if not a section search, provide a helpful conversational response about the document content"
      }

      Rules:
      - Set is_section_search to true ONLY if the query explicitly mentions a section title from the available sections, page numbers, or uses words like "show me", "find", "go to", "section", "chapter"
      - Set is_section_search to false for general questions, explanations, or conceptual queries (even if they relate to the document content)
      - For section searches, try to find the best matching section title from the available sections
      - For general questions, provide a helpful conversational response in the llm_response field
      - ALWAYS include the llm_response field in your JSON response
    PROMPT
  end

  def parse_llm_response(content)
    # Try to extract JSON from the response
    json_match = content.match(/\{.*\}/m)
    if json_match
      begin
        # Clean up the JSON string by removing escaped quotes and newlines
        json_str = json_match[0].gsub('\\"', '"').gsub('\\n', " ").gsub("\\", "")
        parsed = JSON.parse(json_str)

        # If the llm_response field contains JSON, try to parse it
        if parsed["llm_response"] && parsed["llm_response"].is_a?(String) && parsed["llm_response"].start_with?("{")
          begin
            # Clean up the nested JSON string
            nested_json_str = parsed["llm_response"].gsub('\\"', '"').gsub('\\n', " ").gsub("\\", "")
            nested_json = JSON.parse(nested_json_str)
            # Replace the main response with the nested JSON
            parsed = nested_json
          rescue JSON::ParserError => e
            Rails.logger.error "Nested JSON parsing error: #{e.message}"
            # If nested JSON parsing fails, keep the original
          end
        end

        parsed
      rescue JSON::ParserError => e
        Rails.logger.error "JSON parsing error: #{e.message}"
        Rails.logger.error "Content: #{content}"
        fallback_parsing(content)
      end
    else
      fallback_parsing(content)
    end
  end

  def fallback_parsing(content)
    # Fallback parsing if JSON extraction fails
    is_section_search = content.downcase.include?("section") ||
                       content.downcase.include?("chapter") ||
                       content.downcase.include?("page")

    {
      "is_section_search" => is_section_search,
      "target_section" => nil,
      "confidence" => 0.5,
      "reasoning" => "Fallback parsing used due to JSON parsing error",
      "llm_response" => content
    }
  end

  def fallback_analysis(query, available_sections)
    query_lower = query.downcase

    # Simple keyword-based analysis
    section_keywords = [ "section", "chapter", "page", "find", "show", "go to" ]
    question_keywords = [ "what", "how", "why", "explain", "tell me", "describe" ]

    is_section_search = section_keywords.any? { |keyword| query_lower.include?(keyword) }
    is_question = question_keywords.any? { |keyword| query_lower.include?(keyword) }

    # If it's clearly a question, prioritize that
    if is_question && !is_section_search
      {
        "is_section_search" => false,
        "target_section" => nil,
        "confidence" => 0.7,
        "reasoning" => "Fallback analysis: Query contains question keywords",
        "llm_response" => "I'm sorry, but I'm having trouble connecting to the AI service right now. Please try searching for specific sections using keywords like 'section', 'chapter', or 'page'."
      }
    else
      # Try to find matching sections
      target_section = available_sections.find do |section|
        section["title"].downcase.include?(query_lower) ||
        query_lower.include?(section["title"].downcase)
      end

      {
        "is_section_search" => true,
        "target_section" => target_section&.dig("title"),
        "confidence" => target_section ? 0.8 : 0.6,
        "reasoning" => "Fallback analysis: Using keyword matching",
        "llm_response" => nil
      }
    end
  end
end
