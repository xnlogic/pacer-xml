module PacerXml
  module XmlRoute
    def trees(key_map = {})
      to_route.map(route_name: 'trees') do |node|
        node.tree(key_map)['document']
      end.route
    end

    def import(graph, opts = {})
      cache = opts[:cache]
      to_route.process(route_name: 'import') do |node|
        graph.transaction do
          if opts[:cache] == false
            BuildGraph.new(graph, node, opts)
          else
            cache = BuildGraphCached.new(graph, node, opts.merge(cache: cache)).cache
          end
        end
      end.route
    end
  end
  Pacer::RouteBuilder.current.element_types[:xml] = [XmlRoute]
end
