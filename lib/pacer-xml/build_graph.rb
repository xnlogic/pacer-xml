require 'set'

module PacerXml
  class GraphVisitor
    attr_reader :graph
    attr_accessor :depth
    attr_reader :rename, :html

    def initialize(graph, doc, opts = {})
      @graph = graph
      @html = (opts[:html] || []).map(&:to_s).to_set
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
      print('  ' * depth) if depth
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
      return nil if html? e
      tell e.parent.description if e.name == 'p'
      raise '??' if e.name == 'p'
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
      return nil if html? rel
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
    attr_reader :cache
    attr_accessor :fields

    def initialize(graph, doc, opts = {})
      if opts[:cache]
        @cache = opts[:cache]
      else
        @cache = Hash.new { |h, k| h[k] = {} }
        @cache[:hits] = Hash.new 0
        @cache[:size] = 0
        @cache[:kill] = nil
        @cache[:skip] = Set[]
      end
      super
      #tell "CACHE size #{ cache[:size] },  hits:"
      if
      tell '-----------------'
      cache.each do |k, adds|
        next unless k.is_a? String
        hits = cache[:hits][k]
        tell("%40s: %6s / %6s --- %0.5f" % [k, hits, adds, (hits/adds.to_f)])
      end
    end

    def cacheable?(e)
      not cache[:skip].include?(e.name) and not visit_vertex_fields(e).empty?
    end

    def get_cached(e)
      if cacheable?(e)
        id = cache[e.name][visit_vertex_fields(e).hash]
        #tell "cache hit: #{ e.description }" if el
        if id
          cache[:hits][e.name] += 1
          graph.vertex(id)
        end
      end
    end

    def set_cached(e, el)
      return unless el
      if cacheable?(e)
        ct = cache[e.name]
        kill = cache[:kill]
        if kill and cache[:hits][e.name] == 0 and ct.length > kill
          tell "cache kill #{ e.description }"
          cache[:skip] << e.name
          cache[:size] -= ct.length
          cache[e.name] = []
        else
          ct[visit_vertex_fields(e).hash] = el.element_id
          cache[:size] += 1
        end
      end
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
