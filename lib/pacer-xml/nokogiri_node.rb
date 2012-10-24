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


class Nokogiri::XML::Node
  def tree(key_map = {})
    c = elements.map { |x| x.tree(key_map) }.compact
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
      "#<Element #{ name } [#{ elements.map(&:name).uniq.join(', ') }]>"
    end
  end

  def description
    s = if property?
      "property"
    elsif container?
      'container'
    elsif vertex?
      'vertex'
    else
      'other'
    end
    "#{ s } #{ name }"
  end

  def property?
    children.all? &:text?
  end

  def container?
    not property? and
      elements.map(&:name).uniq.length == 1 and
      elements.all? { |e| e.vertex? or e.container? }
  end

  def vertex?
    not property? and not container?
  end

  def properties
    elements.select(&:property?)
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
    elements.select &:vertex?
  end

  def contained_rels
    if container?
      elements.select(&:vertex?) +
        elements.select(&:container?).flat_map(&:contained_rels)
    else
      []
    end
  end

  def many_rels
    elements.select &:container?
  end

  def rels_hash
    result = Hash.new { |h, k| h[k] = [] }
    one_rels.each  { |e| result[e.name] << e }
    many_rels.each { |e| result[e.name] += e.contained_rels }
    result
  end
end
