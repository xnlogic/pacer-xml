require_relative 'pacer-xml/version'
require 'nokogiri'
require 'pacer'

module PacerXml
  class << self
    # Returns the time pacer-xml was last reloaded (or when it was started).
    def reload_time
      if defined? @reload_time
        @reload_time
      else
        START_TIME
      end
    end

    # Reload all Ruby modified files in the pacer-xml library. Useful for debugging
    # in the console. Does not do any of the fancy stuff that Rails reloading
    # does. Certain types of changes will still require restarting the session.
    def reload!
      require 'pathname'
      Pathname.new(File.expand_path(__FILE__)).parent.find do |path|
        if path.extname == '.rb' and path.mtime > reload_time
          puts path.to_s
          load path.to_s
        end
      end
      @reload_time = Time.now
    end
  end
end

require_relative 'pacer-xml/build_graph'
require_relative 'pacer-xml/nokogiri_node'
require_relative 'pacer-xml/xml_route'
require_relative 'pacer-xml/sample'

module Pacer
  class << self
    def xml(file, start_chunk = nil, end_chunk = nil)
      PacerXml::XmlStream.new(file, start_chunk, end_chunk).to_route
    end
  end
end
