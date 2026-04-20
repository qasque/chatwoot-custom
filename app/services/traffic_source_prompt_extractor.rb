require 'open3'

class TrafficSourcePromptExtractor
  class UnsupportedFormatError < StandardError; end
  class EmptyFileError < StandardError; end
  class ExtractionError < StandardError; end

  def initialize(file)
    @file = file
  end

  def extract!
    raise EmptyFileError, 'Uploaded file is empty' if raw_data.blank?

    text = case extension
           when '.txt' then extract_txt
           when '.pdf' then extract_pdf
           when '.docx' then extract_docx
           when '.doc' then extract_doc
           else
             raise UnsupportedFormatError, "Unsupported file format: #{extension}"
           end

    cleaned = text.to_s.strip
    raise EmptyFileError, 'Prompt content cannot be empty' if cleaned.blank?

    cleaned
  rescue UnsupportedFormatError, EmptyFileError
    raise
  rescue StandardError => e
    raise ExtractionError, "Could not extract text from file: #{e.message}"
  end

  private

  attr_reader :file

  def extension
    @extension ||= File.extname(file.original_filename.to_s).downcase
  end

  def raw_data
    @raw_data ||= begin
      file.rewind if file.respond_to?(:rewind)
      file.read
    end
  end

  def extract_txt
    raw_data.to_s.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace)
  end

  def extract_pdf
    with_tempfile('.pdf') do |path|
      stdout, stderr, status = Open3.capture3('pdftotext', '-layout', path, '-')
      raise ExtractionError, stderr.presence || 'pdftotext failed' unless status.success?

      stdout
    end
  end

  def extract_docx
    body_xml = nil
    with_tempfile('.docx') do |path|
      stdout, stderr, status = Open3.capture3('unzip', '-p', path, 'word/document.xml')
      raise ExtractionError, stderr.presence || 'Could not read DOCX' unless status.success?
      body_xml = stdout
    end
    document = Nokogiri::XML(body_xml)
    document.xpath('//w:t', 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main').map(&:text).join(' ')
  end

  def extract_doc
    with_tempfile('.doc') do |path|
      stdout, stderr, status = Open3.capture3('antiword', path)
      raise ExtractionError, stderr.presence || 'antiword failed' unless status.success?

      stdout
    end
  end

  def with_tempfile(ext)
    Tempfile.create(['traffic_source_prompt', ext]) do |tmp|
      tmp.binmode
      tmp.write(raw_data)
      tmp.flush
      tmp.rewind
      yield tmp.path
    end
  end
end
