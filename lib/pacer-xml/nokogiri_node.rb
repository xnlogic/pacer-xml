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
