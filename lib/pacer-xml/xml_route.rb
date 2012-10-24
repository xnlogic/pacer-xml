module XmlRoute
  def trees(key_map = {})
    to_route.map(route_name: 'trees') { |node| node.tree(key_map)['document'] }.route
  end

  def import(graph, rename = {})
    to_route.process(route_name: 'import') { |node| BuildGraph.new(graph, node, rename) }.route
  end
end
Pacer::RouteBuilder.current.element_types[:xml] = [XmlRoute]
