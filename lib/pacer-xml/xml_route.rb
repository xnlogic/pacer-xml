module PacerXml
  module XmlRoute
    def help(section = nil)
      case section
      when nil
        puts <<HELP
This is included via the pacer-xml gem plugin.

pacer-xml uses Nokogiri for its xml parsing. Each element in an xml route
is the first child element of the Nokogiri::XML::Document element. To get at
the document element, simply call #parent on the element.

An xml route can be created, transformed, filtered and otherwise
processed by all standard Pacer routes. For instance, if a graph element
has a property with xml data in it, we could process it as follows:

  g.v.map(element_type: :xml) { |v| Nokogiri(v[:xml]) }

Method help sections:
  :xml
  :import

HELP
      when :xml
        puts <<HELP



Turn an xml file into a stream of xml nodes. Scans the xml file
line-by-line and uses arguments defined in start_section and end_section
to extract sections from the file.

Pacer.xml(file, start_section = nil, end_section = nil)

file:          String | IO
    String           path to an xml file to read
    IO               an open resource that responds to #each_line
  start_section: String | Symbol | Regex | Proc  (optional)
    String | Symbol  name of xml tag to use as the root node of each
                     section of xml. The end_section will automatically be
                     set to the closing tag.  This uses very simple regex
                     matching.
    Regex            If it matches, start the section from this line
    Proc             proc { |line| }
                     If it results in a truthy value, starts collecting
                     lines for the next section of xml.
  end_section:   Proc  (optional)
    Regex            If it matches, end the section including this line
    Proc             proc { |line, lines| }
                     - If it results in a truthy value to indicate that the
                       current line is the last line in a section.
                     - if it results in an Array, pass the result of
                       joining the array to Nokogiri for the next section.

HELP
      when :import
        puts <<HELP
Turn the tree of xml in each node in the stream

xml_route.import(graph, opts = {})

  graph: PacerGraph   The graph to load the data into.
  opts:  Hash
    :cache  false | Hash
      false              disable caching
      stats: true        enable occasional dump of cache info
    :rename Hash         map of { 'old-name' => 'new-name' }
    :html   Array        set of tag names to treat as containing HTML
    :skip   Array        set of tag or attribute names to skip

Produces a vertex route where each vertex is the root vertex for each xml tree.

Look at the source of lib/pacer-xml/sample.rb a good example.

HELP
      else
        super
      end
      description
    end

    def children
      flat_map(element_type: :xml) { |x| x.children.to_a }
    end

    def names
      map element_type: :string, &:name
    end

    def text_nodes
      select &:text?
    end

    def elements
      select &:element?
    end

    def fields
      elements.map element_type: :hash, &:fields
    end

    def import(graph, opts = {})
      if opts[:cache] == false
        builder = BuildGraph.new(graph, opts)
      else
        builder = BuildGraphCached.new(graph, opts)
      end
      graph.vertex_name ||= proc { |v| v[:type] }
      to_route.map(route_name: 'import', graph: graph, element_type: :vertex, modules: [ImportHelp]) do |node|
        graph.transaction do
          builder.build(node)
        end
      end.route
    end

    module ImportHelp
      def help(section = nil)
        case section
        when nil
          back.help :import
        else
          super
        end
        description
      end
    end
  end
  Pacer::RouteBuilder.current.element_types[:xml] = [XmlRoute]
end
