module PacerXml
  class XmlStream
    include Enumerable

    attr_reader :file, :start_chunk, :end_chunk

    def initialize(file, start_chunk = nil, end_chunk = nil)
      @file = file
      start_chunk ||= /<\?xml/
      @start_chunk = build_rule :start, start_chunk
      @end_chunk = end_chunk ? build_rule(:end, end_chunk) : @start_chunk
    end

    def each
      return to_enum unless block_given?
      File.open file do |f|
        lines = []
        collecting = false
        f.each_line do |line|
          if collecting
            ec = end_chunk.call line, lines
            lines = ec if ec.is_a? Array
            if ec
              yield Nokogiri::XML(lines.join).first_element_child if lines
              collecting = false
            else
              lines << line
            end
          end
          unless collecting
            if start_chunk.call line
              lines = [line]
              collecting = true
            end
          end
        end
        if collecting
          ec = end_chunk.call nil, lines
          lines = ec if ec.is_a? Array
          if lines
            begin
              xml = Nokogiri::XML(lines.join).first_element_child
            rescue StandardError
              # ignore xml errors here
            else
              yield xml
            end
          end
        end
      end
    end

    def to_route(opts = {})
      super(opts.merge(info: file, element_type: :xml)).route
    end

    private

    def build_rule(type, rule)
      if rule.is_a? String
        rule = "/#{rule}" if type == :end
        rule = /<#{rule}\b/
      end
      if rule.is_a? Proc
        rule
      else
        proc do |line, lines|
          !!(rule =~ line)
        end
      end
    end
  end
end
