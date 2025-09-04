require_relative "../services/llm_service"

class SearchController < ApplicationController
  def index
    respond_to do |format|
      format.html
      format.json do
        query = params[:q]&.strip

        unless query.present?
          render json: { results: [], llm_response: nil }
          return
        end

        # Get all PDFs that have been processed
        pdfs = Pdf.where(processing_status: "completed")

        # Collect all available sections from all PDFs
        all_sections = []
        pdf_sections_map = {}

        pdfs.each do |pdf|
          # Get sections from pdf_sections table
          sections = pdf.pdf_sections
          if sections.any?
            # Convert sections to the expected format
            sections_with_pdf = sections.map do |section|
              {
                "title" => section.title,
                "page" => section.page,
                "pdf_id" => pdf.id,
                "pdf_name" => pdf.name,
                "section_number" => section.section_number
              }
            end
            all_sections.concat(sections_with_pdf)
            pdf_sections_map[pdf.id] = sections_with_pdf
          end
        end

        # Use LLM to analyze the query
        begin
          llm_service = LlmService.new
          Rails.logger.info "LlmService class: #{llm_service.class}"
          Rails.logger.info "LlmService file: #{LlmService.instance_method(:analyze_search_query).source_location}"
          analysis = llm_service.analyze_search_query(query, all_sections)
          Rails.logger.info "Analysis result: #{analysis.inspect}"
        rescue => e
          Rails.logger.error "LLM service error: #{e.message}"
          # Fallback to simple search
          results = perform_fallback_search(query, pdf_sections_map)
          render json: {
            results: results,
            llm_response: nil,
            error: "LLM service unavailable: #{e.message}"
          }
          return
        end

        if analysis[:error]
          # Fallback to original search if LLM fails
          Rails.logger.error "LLM analysis failed: #{analysis[:error]}"
          results = perform_fallback_search(query, pdf_sections_map)
          render json: {
            results: results,
            llm_response: nil,
            error: analysis[:error]
          }
          return
        end

        if analysis["is_section_search"] && analysis["target_section"]
          # LLM determined this is a section search and found a target
          target_section = analysis["target_section"]
          results = perform_section_search(target_section, pdf_sections_map)

          render json: {
            results: results,
            llm_response: nil,
            analysis: analysis,
            search_type: "section"
          }
        elsif analysis["is_section_search"]
          # LLM determined this is a section search but no specific target found
          # Fall back to fuzzy search
          results = perform_fallback_search(query, pdf_sections_map)
          render json: {
            results: results,
            llm_response: nil,
            analysis: analysis,
            search_type: "section_fallback"
          }
        else
          # LLM determined this is a general question
          render json: {
            results: [],
            llm_response: analysis["llm_response"],
            analysis: analysis,
            search_type: "conversational"
          }
        end
      end
    end
  end

  private

  def perform_section_search(target_section, pdf_sections_map)
    results = []

    pdf_sections_map.each do |pdf_id, sections|
      matching_sections = sections.select do |section|
        section["title"].downcase.include?(target_section.downcase) ||
        target_section.downcase.include?(section["title"].downcase)
      end

      if matching_sections.any?
        results << {
          pdf_id: pdf_id,
          pdf_name: sections.first["pdf_name"],
          sections: matching_sections
        }
      end
    end

    results
  end

  def perform_fallback_search(query, pdf_sections_map)
    query_lower = query.downcase
    results = []

    pdf_sections_map.each do |pdf_id, sections|
      matching_sections = sections.select do |section|
        section_title = section["title"]&.downcase || ""
        section_title.include?(query_lower) ||
        query_lower.split(/\s+/).any? { |word| section_title.include?(word) }
      end

      if matching_sections.any?
        results << {
          pdf_id: pdf_id,
          pdf_name: sections.first["pdf_name"],
          sections: matching_sections
        }
      end
    end

    results
  end
end
