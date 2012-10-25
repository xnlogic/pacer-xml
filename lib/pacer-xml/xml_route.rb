module PacerXml
  module XmlRoute
    def trees(key_map = {})
      to_route.map(route_name: 'trees') do |node|
        node.tree(key_map)['document']
      end.route
    end

    def import(graph, opts = {})
      if opts[:cache] == false
        builder = BuildGraph.new(graph, opts)
      else
        builder = BuildGraphCached.new(graph, opts)
        if opts[:cache].is_a? Hash
          builder.cache.merge! opts[:cache]
        end
      end
      to_route.map(route_name: 'import', graph: graph, element_type: :vertex) do |node|
        graph.transaction do
          builder.build(node)
        end
      end.route
    end
  end
  Pacer::RouteBuilder.current.element_types[:xml] = [XmlRoute]
end
