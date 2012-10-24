require 'nokogiri'
require 'ap'
require 'pp'
require 'pacer'
require 'pacer-neo4j'
require 'pacer-dex'
require 'pacer-orient'
require 'benchmark'







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


