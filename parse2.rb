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
  def tree
    c = children.map(&:tree).compact
    if c.empty?
      name
    else
      ct = {}
      texts = []
      attrs = {}
      attrs = Hash[attributes.map { |k, a| [k, a.value] }] if respond_to? :attributes
      c.each do |h|
        if h.is_a? String
          texts << h
          next
        end
        h.each do |name, value|
          if ct.key? name
            if ct[name].is_a? Array
              ct[name] << value
            else
              ct[name] = [ct[name], value]
            end
          else
            ct[name] = value
          end
        end
      end
      ct.merge! attrs
      if ct.empty?
        if texts.count < 2
          { name => texts.first }
        else
          { name => texts }
        end
      elsif texts.any?
        { name => ct }
      else
        { name => ct }
      end
    end
  end

  def inspect
    tree.inspect
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
end


class Nokogiri::XML::Text
  def tree
    text unless text =~ /\A\s*\Z/
  end

  def inspect
    text
  end
end

def parse_document(str, g)
  doc = Nokogiri::XML str
  $doc = doc.tree
  #patent doc.at_css('us-bibliographic-data-grant'), g
end

