module PacerXml
  module XmlRoute
    def import(graph, opts = {})
      if opts[:cache] == false
        builder = BuildGraph.new(graph, opts)
      else
        builder = BuildGraphCached.new(graph, opts)
      end
      graph.vertex_name ||= proc { |v| v[:type] }
      to_route.map(route_name: 'import', graph: graph, element_type: :vertex) do |node|
        graph.transaction do
          builder.build(node)
        end
      end.route
    end
  end
  Pacer::RouteBuilder.current.element_types[:xml] = [XmlRoute]
end
