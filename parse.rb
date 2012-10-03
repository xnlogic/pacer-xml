# Data files:
# https://explore.data.gov/Business-Enterprise/Patent-Grant-Bibliographic-Text-1976-Present-/8du5-jxih
# http://www.google.com/googlebooks/uspto-patents-grants-biblio.html

require 'nokogiri'
require 'pp'
require 'pacer'
require 'pacer-dex'

def parse_document(str, g)
  doc = Nokogiri::XML str
  patent doc.at_css('us-bibliographic-data-grant'), g
end

def parse(file, g)
  File.open file do |f|
    xml = nil
    f.each_line do |line|
      if line[0...5] == '<?xml'
        return parse_document xml.join, g if xml
        xml = [line]
      else
        xml << line
      end
    end
  end
end

def patent(el, g)
  application(el, g)
  publication(el, g)
  text(el, 'invention-title')
  text(el, 'us-application-series-code')

  integer(el, 'length-of-grant')
  integer(el, 'number-of-claims')
  integer(el, 'number-of-drawing-sheets')
  integer(el, 'number-of-figures')

  citations(el, g)
  # skipped citations
  # skipped related documents
  applicants(el, g)
  agents(el, g)
  examiners(el, g)
end


def publication(el, g)
  document el.at_css('publication-reference'), g
end

def application(el, g)
  document el.at_css('application-reference'), g
end

def citations(el, g)
  el.css('citation').map { |c| citation c, g }
end

def citation(el, g)
  doc = document el, g
  by = cited_by el, g
end

def applicants(el, g)
  el.css('applicants').map do |app|
    applicant app, g
  end
end

def applicant(el, g)
  entity(el, g)
end

def agents(el, g)
  el.css('agents').map do |app|
    agent app, g
  end
end

def agent(el, g)
  el.attr('rep-type')
  entity(el, g)
end

def examiners(el, g)
  el.css('primary-examiner').map do |e|
    entity(e, g)
  end
  el.css('assistant-examiner').map do |e|
    entity(e, g)
  end
end


def document(el, g)
  d = el.at_css('document-id')
  text(d, 'country')
  text(d, 'doc-number')
  text(d, 'kind')
  text(d, 'date')
  author d, g
end

def entity(el, g)
  e = el.at_css('addressbook')
  text(e, 'orgname')
  text(e, 'last-name')
  text(e, 'first-name')
  text(e, 'department')
  text(e, 'address city')
  text(e, 'address state')
  text(e, 'address country')
end

def author(el, g)
  text(el, 'name')
end

def cited_by(el, g)
  text(el, 'category')
end

def text(el, tag)
  t = el.at_css(tag)
  t.text if t
end

def integer(el, tag)
  t = text(el, tag)
  t.to_i if t
end
