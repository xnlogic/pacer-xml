# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "pacer-xml/version"

Gem::Specification.new do |s|
  s.name        = "pacer-xml"
  s.version     = PacerXml::VERSION
  s.platform    = 'java'
  s.authors     = ["Darrick Wiebe"]
  s.email       = ["dw@xnlogic.com"]
  s.homepage    = "http://xnlogic.com"
  s.summary     = %q{XML streaming and graph import for Pacer}
  s.description = s.summary

  s.add_dependency 'pacer', PacerXml::PACER_VERSION
  s.add_dependency 'pacer-neo4j', ">= 2.1"
  s.add_dependency 'nokogiri'

  s.rubyforge_project = "pacer-xml"

  s.files = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_paths = ["lib"]
end
