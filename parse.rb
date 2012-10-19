# Data files:
# https://explore.data.gov/Business-Enterprise/Patent-Grant-Bibliographic-Text-1976-Present-/8du5-jxih
# http://www.google.com/googlebooks/uspto-patents-grants-biblio.html

require 'nokogiri'
require 'pp'
require 'pacer'
require 'pacer-neo4j'
require 'benchmark'

def prep_graph(g)

  g.safe_transactions = false
  g.create_key_index 'type', :vertex
  g.create_key_index 'org_name', :vertex
  g.create_key_index 'last_name', :vertex
  g.key_index_cache :vertex, 'type', 100000
  g.key_index_cache :vertex, 'org_name', 100000
  g.key_index_cache :vertex, 'last_name', 100000
  g.use_wrapper com.tinkerpop.blueprints.util.wrappers.batch.BatchGraph
end

def import_batch
  g = Pacer.neo4j "neo/#{Time.now.to_i}"
  w = g.use_wrapper com.tinkerpop.blueprints.util.wrappers.batch.BatchGraph
  t = Benchmark.realtime do
    parse 'ipgb20120103.xml', w
  end
  puts
  puts "batch (neo): #{ t }"
  g
end

def import_batch_batch
  n = "neo/#{Time.now.to_i}"
  g = Pacer.neo_batch n
  w = g.use_wrapper com.tinkerpop.blueprints.util.wrappers.batch.BatchGraph
  t = Benchmark.realtime do
    begin
      parse 'ipgb20120103.xml', w
    ensure
      g.shutdown
    end
  end
  puts
  puts "batch (neo batch): #{ t }"
  Pacer.neo4j n
end

# this is the entry point
def parse(file, g)
  lines = 0
  $docs = {}
  $authors = {}
  File.open file do |f|
    lines = f.each_line.count.to_f
  end
  File.open file do |f|
    xml = nil
    n = 0
    f.each_line do |line|
      n += 1
      if line[0...5] == '<?xml'
        g.transaction do
          parse_document n, xml.join, g if xml
          print '.'
        end
        return if n/lines > 0.1
        xml = [line]
      else
        xml << line
      end
    end
  end
end

def parse_document(n, str, g)
  doc = Nokogiri::XML str
  patent n, doc.at_css('us-bibliographic-data-grant'), g
end

def patent(n, el, g)
  p = g.vertex("patent #{n}") || g.create_vertex("patent #{n}",
                                                 type: "patent",
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
  applicants(el, g).each do |a|
    add_edge p, :applicant, a
  end
  agents(p, el, g)
  examiners(p, el, g)
  p
end

def add_edge(from, label, to, args = nil)
  if from and to
    from.graph.create_edge nil, from, to, label, args
  end
end

def publication(el, g)
  document "publication", el.at_css('publication-reference'), g
end

def application(el, g)
  document "application", el.at_css('application-reference'), g
end

def citations(p, el, g)
  el.css('citation').each { |c| citation p, c, g }
end

def citation(p, el, g)
  add_edge p, :citation, document("citation", el, g), citation_type: text(el, 'category')
end

def applicants(el, g)
  el.css('applicants').map do |app|
    applicant app, g
  end.compact
end

def applicant(el, g)
  entity(el, g)
end

def agents(p, el, g)
  el.css('agents').each do |app|
    agent p, app, g
  end
end

def agent(p, el, g)
  label = el.attr('rep-type')
  label = 'agent' if not label or label =~ /\A\s*\Z/
  add_edge p, label, entity(el, g), type: "agent"
end

def examiners(p, el, g)
  el.css('primary-examiner').each do |e|
    ent = entity(e, g)
    add_edge ent, :examined, p if ent
  end
  el.css('assistant-examiner').each do |e|
    ent = entity(e, g)
    add_edge ent, :examined, p if ent
  end
end


def document(type, el, g)
  d = el.at_css('document-id')
  if d
    doc_number = text(d, 'doc-number')
    doc = g.vertex(doc_number) || g.create_vertex(doc_number,
                                          doc_number: doc_number,
                                          type: "document",
                                          document_type: type,
                                          country: text(d, 'country'),
                                          kind: text(d, 'kind'),
                                          date: text(d, 'date'),
                                          other: text(d, 'othercit'))
    add_edge author(d, g), :wrote, doc
    doc
  end
end

def entity(el, g)
  e = el.at_css('addressbook')
  if e
    id = [text(e, 'orgname'), text(e, 'last-name'), text(e, 'first-name')]
    g.vertex(id) or g.create_vertex(id, type: "entity",
                    org_name: text(e, 'orgname'),
                    last_name: text(e, 'last-name'),
                    first_name: text(e, 'first-name'),
                    department: text(e, 'department'),
                    city: text(e, 'address city'),
                    state: text(e, 'address state'),
                    country: text(e, 'address country'))
  end
end

def author(el, g)
  name = text(el, 'name')
  if name
    g.vertex(name) or g.create_vertex(name, type: "author", name: name)
  end
end

def text(el, tag)
  t = el.at_css(tag)
  t.text if t
end

def integer(el, tag)
  t = text(el, tag)
  t.to_i if t
end
