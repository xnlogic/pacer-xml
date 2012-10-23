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

  attr_reader :file, :is_full_chunk

  def initialize(file, is_full_chunk = nil)
    @file = file
    @is_full_chunk = is_full_chunk || proc do |lines, line|
      line[0...5] == '<?xml'
    end
  end

  def each
    return to_enum unless block_given?
    File.open file do |f|
      lines = nil
      f.each_line do |line|
        if lines.nil? or is_full_chunk.call lines, line
          yield Nokogiri::XML lines.join if lines
          lines = [line]
        else
          lines << line
        end
      end
    end
  end

  def trees(key_map = {})
    to_route.map { |node| node.tree(key_map) }
  end
end

class Nokogiri::XML::Node
  def tree(key_map = {})
    c = children.map { |x| x.tree(key_map) }.compact
    if c.empty?
      key_map.fetch(name, name)
    else
      ct = {}
      texts = []
      attrs = {}
      attrs = Hash[attributes.map { |k, a|
        k = key_map.fetch(k, k)
        [k, a.value] if k
      }.compact] if respond_to? :attributes
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
    "#<Node #{ name }: #{ tree.keys.join( ', ') }>"
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
    text
  end
end
