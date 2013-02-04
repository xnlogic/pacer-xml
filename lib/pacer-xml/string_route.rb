module Pacer
  module Core
    module StringRoute
      def xml_stream(enter = nil, leave = nil, &block)
        enter ||= /<\?xml/
        leave ||= enter
        enter = build_rule :enter, enter
        leave = build_rule :leave, leave
        r = reducer(element_type: :array, enter: enter, leave: leave) do |s, lines|
          lines << s
        end.route
        joined = r.map(element_type: :string, info: 'join', &:join).route
        joined = block.call joined if block
        joined.xml
      end

      def xml
        map(element_type: :xml) do |s|
          Nokogiri::XML(s).first_element_child
        end
      end

      private

      def build_rule(type, rule)
        rule = rule.to_s if rule.is_a? Symbol
        if rule.is_a? String
          if type == :leave
            rule = "/#{rule}"
            add_close_tag = true
          end
          rule = /<#{rule}\b/
        end
        if rule.is_a? Proc
          rule
        elsif add_close_tag
          proc do |line, lines, set_value|
            if line.nil? or rule =~ line
              set_value.call(lines << line)
              true
            end
          end
        else
          proc do |line|
            [] if line.nil? or rule =~ line
          end
        end
      end
    end
  end
end
