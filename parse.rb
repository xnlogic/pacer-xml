# Data files:
# https://explore.data.gov/Business-Enterprise/Patent-Grant-Bibliographic-Text-1976-Present-/8du5-jxih
# http://www.google.com/googlebooks/uspto-patents-grants-biblio.html

require 'nokogiri'
require 'pp'
require 'pacer'
require 'pacer-neo4j'

# this is the entry point
def parse(file, g)
  g.create_key_index 'type', :vertex
  g.create_key_index 'doc_number', :vertex
  g.create_key_index 'org_name', :vertex
  g.create_key_index 'last_name', :vertex
  g.create_key_index 'name', :vertex
  g.create_key_index 'category', :vertex
  g.blueprints_graph.raw_graph.setCheckElementsInTransaction false
  File.open file do |f|
    xml = nil
    f.each_line do |line|
      if line[0...5] == '<?xml'
        g.transaction do
          parse_document xml.join, g if xml
        end
        xml = [line]
      else
        xml << line
      end
    end
  end
ensure
  g.blueprints_graph.raw_graph.setCheckElementsInTransaction true
end

def parse_document(str, g)
  doc = Nokogiri::XML str
  patent doc.at_css('us-bibliographic-data-grant'), g
end

def patent(el, g)
  puts
  puts "PATENTED!"
  p = g.create_vertex(type: "patent",
                      title: text(el, 'invention-title'),
                      code: text(el, 'us-application-series-code'),
                      length: integer(el, 'length-of-grant'),
                      num_claims: integer(el, 'number-of-claims'),
                      num_sheets: integer(el, 'number-of-drawing-sheets'),
                      num_figures: integer(el, 'number-of-figures'))
  add_edge p, :application, application(el, g)
  add_edge p, :publication, publication(el, g)
  citations(p, el, g)
  # skipped related documents
  p.add_edges_to :applicant, applicants(el, g)
  agents(p, el, g)
  examiners(p, el, g)
  p
end

def add_edge(from, label, to, args = nil)
  if from and to
    print '-'
    from.graph.create_edge nil, from, to, label, args
  else
    '*'
  end
end

def publication(el, g)
  print 'u'
  document "publication", el.at_css('publication-reference'), g
end

def application(el, g)
  print 'a'
  document "application", el.at_css('application-reference'), g
end

def citations(p, el, g)
  el.css('citation').each { |c| citation p, c, g }
end

def citation(p, el, g)
  print 'c'
  add_edge p, :citation, document("citation", el, g), citation_type: text(el, 'category')
end

def applicants(el, g)
  el.css('applicants').map do |app|
    applicant app, g
  end.compact
end

def applicant(el, g)
  print '^'
  entity(el, g)
end

def agents(p, el, g)
  el.css('agents').each do |app|
    agent p, app, g
  end
end

def agent(p, el, g)
  print 'A'
  add_edge p, el.attr('rep-type'), entity(el, g), type: "agent"
end

def examiners(p, el, g)
  el.css('primary-examiner').each do |e|
    print 'E'
    ent = entity(e, g)
    add_edge ent, :examined, p if ent
  end
  el.css('assistant-examiner').each do |e|
    print 'e'
    ent = entity(e, g)
    add_edge ent, :examined, p if ent
  end
end


def document(type, el, g)
  d = el.at_css('document-id')
  if d
    basic = {
      type: "document",
      document_type: type,
      doc_number: text(d, 'doc-number')
    }
    doc = g.v(basic).first or g.create_vertex(basic.merge(country: text(d, 'country'),
                                                          kind: text(d, 'kind'),
                                                          date: text(d, 'date')))
    add_edge author(d, g), :wrote, doc
    doc
  end
end

def entity(el, g)
  e = el.at_css('addressbook')
  if e
    basic = {
      type: "entity",
      org_name: text(e, 'orgname'),
      last_name: text(e, 'last-name'),
      first_name: text(e, 'first-name')
    }
    g.v(basic).first or g.create_vertex(basic.merge(department: text(e, 'department'),
                                              city: text(e, 'address city'),
                                              state: text(e, 'address state'),
                                              country: text(e, 'address country')))
  end
end

def author(el, g)
  print 'h'
  name = text(el, 'name')
  props = { type: "author", name: name }
  g.v(props).first or g.create_vertex props
end

def text(el, tag)
  t = el.at_css(tag)
  t.text if t
end

def integer(el, tag)
  t = text(el, tag)
  t.to_i if t
end
