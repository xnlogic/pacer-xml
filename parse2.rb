require 'nokogiri'
require 'ap'
require 'pp'
require 'pacer'
require 'pacer-neo4j'
require 'pacer-dex'
require 'pacer-orient'
require 'benchmark'

class XmlChunks
  include Enumerable

  attr_reader :file, :start_chunk, :end_chunk

  def initialize(file, start_chunk = nil, end_chunk = nil)
    @file = file
    start_chunk ||= /<\?xml/
    @start_chunk = build_rule :start, start_chunk
    @end_chunk = end_chunk ? build_rule(:end, end_chunk) : @start_chunk
  end

  def each
    return to_enum unless block_given?
    File.open file do |f|
      lines = []
      collecting = false
      f.each_line do |line|
        if collecting
          ec = end_chunk.call line, lines
          lines = ec if ec.is_a? Array
          if ec
            yield Nokogiri::XML lines.join if lines
            collecting = false
          else
            lines << line
          end
        end
        unless collecting
          if start_chunk.call line
            lines = [line]
            collecting = true
          end
        end
      end
    end
  end

  def to_route(opts = {})
    super(opts.merge(route_name: 'xml', element_type: :xml)).route
  end

  private

  def build_rule(type, rule)
    if rule.is_a? String
      rule = "/#{rule}" if type == :end
      rule = /<#{rule}\b/
    end
    if rule.is_a? Proc
      rule
    else
      proc do |line, lines|
        !!(rule =~ line)
      end
    end
  end
end


module XmlRoute
  def trees(key_map = {})
    to_route.map(route_name: 'trees') { |node| node.tree(key_map)['document'] }.route
  end

  def import(graph, rename = {})
    to_route.process(route_name: 'import') { |node| BuildGraph.new(graph, node, rename) }.route
  end
end
Pacer::RouteBuilder.current.element_types[:xml] = [XmlRoute]


class Nokogiri::XML::Node
  def tree(key_map = {})
    c = children.map { |x| x.tree(key_map) }.compact
    if c.empty?
      key_map.fetch(name, name)
    else
      ct = {}
      texts = []
      attrs = {}
      if respond_to? :attributes
        attrs = Hash[attributes.map { |k, a|
          k = key_map.fetch(k, k)
          [k, a.value] if k
        }.compact]
      end
      c.each do |h|
        if h.is_a? String
          texts << h
          next
        end
        h.each do |name, value|
          if ct.key? name
            if ct[name].is_a? Array
              ct[name] << value unless ct[name].include? value
            elsif ct[name] != value
              ct[name] = [ct[name], value]
            end
          else
            ct[name] = value
          end
        end
      end
      ct.merge! attrs
      key = key_map.fetch(name, name)
      if key
        if ct.empty?
          if texts.count < 2
            { key => texts.first }
          else
            { key => texts.uniq }
          end
        elsif texts.any?
          { key => ct }
        else
          { key => ct }
        end
      end
    end
  end

  def inspect
    if children.all? &:text?
      "#<Property #{ name }>"
    else
      "#<Element #{ name } [#{ children.reject(&:text?).map(&:name).uniq.join(', ') }]>"
    end
  end

  def property?
    children.all? &:text?
  end

  def container?
    children.all? &:element?
  end

  def element?
    not property? and not container?
  end

  def properties
    children.select(&:property?)
  end

  def attrs
    if respond_to? :attributes
      attributes
    else
      {}
    end
  end

  def fields
    result = {}
    attrs.each do |name, attr|
      result[name] = attr.value
    end
    properties.each do |e|
      result[e.name] = e.text
    end
    result['type'] = name
    result
  end

  def one_rels
    children.select &:element?
  end

  def many_rels
    children.select &:container?
  end

  def rels_hash
    result = Hash.new { |h, k| h[k] = [] }
    one_rels.each  { |e| result[e.name] << e }
    many_rels.each { |e| result[e.name] += e.one_rels }
    result
  end
end

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

class Array
  def children
    flat_map do |e|
      case e
      when Hash
        e.children
      else
        []
      end
    end
  end

  def records
    items.select &:record?
  end

  def records?
    not records.empty?
  end

  def rels
    items.reject(&:record?)# .select { |h| h.children.records? }
  end

  def items
    select { |e| e.is_a? Hash }
  end

  def keys
    items.map(&:keys).flatten
  end
end

class Hash
  def children
    values.select { |v| v.is_a? Hash }
  end

  def record?
    values.any? { |v| v.is_a? String }
  end

  def rel?
    not record?
  end

  def properties
    select { |k, v| v.is_a? String }
  end

  def rels
    select { |k, v| v.is_a? Hash }
  end

  def to_graph(parent, type, g)
    if record?
      add_vertex g, type, data
    end
  end

  def key_tree
    Hash[rels.map { |k, v|
      kt = v.key_tree
      if kt.length > 0 and kt.values.all? { |v| v == {} }
        if kt.length == 1
          [k, v.key_tree.keys.first]
        else
          [k, v.key_tree.keys]
        end
      else
        [k, v.key_tree]
      end
    }]
  end
end


class Nokogiri::XML::Text
  def tree(_ = nil)
    text unless text =~ /\A\s*\Z/
  end

  def inspect
    if text =~ /\A\s*\Z/
      "#<(whitespace)>"
    else
      "#<Text #{ text }>"
    end
  end
end
