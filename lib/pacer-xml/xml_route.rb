module PacerXml
  module XmlRoute
    def trees(key_map = {})
      to_route.map(route_name: 'trees') do |node|
        node.tree(key_map)['document']
      end.route
    end

    def import(graph, rename = {})
      to_route.process(route_name: 'import') do |node|
        graph.transaction do
          BuildGraph.new(graph, node, rename)
        end
      end.route
    end
  end
  Pacer::RouteBuilder.current.element_types[:xml] = [XmlRoute]
end
