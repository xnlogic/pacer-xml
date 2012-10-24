module PacerXml
  class BuildGraph
    attr_reader :graph, :rename

    def initialize(graph, doc, rename = {})
      @graph = graph
      @rename = { 'id' => 'identifier' }.merge rename
      if doc.is_a? Nokogiri::XML::Document
        doc.one_rels.each { |e| visit_element e }
      elsif doc.is_a? Enumerable
        doc.select(&:element?).each { |e| visit_element e }
      elsif doc.element?
        visit_element doc
      else
        fail "Don't know what you want to do"
      end
    end

    def visit_vertex_fields(e)
      h = e.fields
      rename.each do |from, to|
        if h.key? from
          h[to] = h.delete from
        end
      end
      h
    end

    def visit_edge_fields(e)
      h = visit_vertex_fields(e)
      h.delete 'type'
      h
    end

    def visit_element(e)
      vertex = graph.create_vertex visit_vertex_fields(e)
      e.one_rels.each do |rel|
        visit_one_rel e, vertex, rel
      end
      e.many_rels.each do |rel|
        visit_many_rels e, vertex, rel
      end
      vertex
    end

    def visit_one_rel(e, vertex, rel)
      graph.create_edge nil, vertex, visit_element(rel), rel.name
    end

    def visit_many_rels(from_e, from, rel)
      attrs = visit_edge_fields rel
      attrs.delete :type
      rel.one_rels.each do |to_e|
        visit_many_rel(from_e, from, rel, to_e, attrs)
      end
    end

    def visit_many_rel(from_e, from, rel, to_e, attrs)
      graph.create_edge nil, from, visit_element(to_e), rel.name, attrs
    end
  end
end
