require 'set'

module PacerXml
  class GraphVisitor
    attr_reader :graph
    attr_accessor :depth
    attr_reader :rename, :html

    def initialize(graph, doc, opts = {})
      @graph = graph
      @html = opts.fetch(:html, []).to_set

      @rename = { 'id' => 'identifier' }.merge opts.fetch(:rename, {})
      self.depth = 0
      if doc.is_a? Nokogiri::XML::Document
        visit_element doc.first_element_child
      elsif doc.element?
        visit_element doc
      elsif doc.is_a? Enumerable
        doc.select(&:element?).each { |e| visit_element e }
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
      html.each do |name|
        name = name.to_s
        child = e.at_xpath(name)
        h[name] = child.inner_html if child
      end
      h
    end

    def visit_edge_fields(e)
      h = visit_vertex_fields(e)
      h.delete 'type'
      h
    end

    def tell(x)
      print('  ' * depth)
      if x.is_a? Hash or x.is_a? Array
        p x
      else
        puts x
      end
    end

    def html?(e)
      html.include? e.name
    end

    def level
      self.depth += 1
      yield
    ensure
      self.depth -= 1
    end
  end

  class BuildGraph < GraphVisitor
    def visit_element(e)
      return if html? e
      level do
        vertex = graph.create_vertex visit_vertex_fields(e)
        e.one_rels.each do |rel|
          visit_one_rel e, vertex, rel
        end
        e.many_rels.each do |rel|
          visit_many_rels e, vertex, rel
        end
        if block_given?
          yield vertex
        else
          vertex
        end
      end
    end

    def visit_one_rel(e, from, rel)
      to = visit_element(rel)
      if from and to
        graph.create_edge nil, from, to, rel.name
      end
    end

    def visit_many_rels(from_e, from, rel)
      level do
        attrs = visit_edge_fields rel
        attrs.delete :type
        rel.contained_rels.map do |to_e|
          visit_many_rel(from_e, from, rel, to_e, attrs)
        end
      end
    end

    def visit_many_rel(from_e, from, rel, to_e, attrs)
      to = visit_element(to_e)
      if from and to
        graph.create_edge nil, from, to, rel.name, attrs
      end
    end
  end


  class BuildGraphCached < BuildGraph
    attr_reader :cache, :skip_cache
    attr_accessor :fields

    def initialize(graph, doc, opts = {})
      @cache = opts.fetch :cache, Hash.new { |h, k| h[k] = {} }
      @skip_cache = opts.fetch :skip_cache, Set[]
      super
    end

    def cacheable?(e)
      not skip_cache.include? e.name and not visit_vertex_fields(e).empty?
    end

    def get_cached(e)
      el = cache[e.name][visit_vertex_fields(e)] if cacheable?(e)
      #tell "cache hit: #{ e.description }" if el
      el
    end

    def set_cached(e, el)
      cache[e.name][visit_vertex_fields(e)] = el if cacheable?(e)
      el
    end

    def visit_vertex_fields(e)
      self.fields ||= super
    end

    def visit_element(e)
      self.fields = nil
      get_cached(e) || set_cached(e, super)
    end
  end
end
