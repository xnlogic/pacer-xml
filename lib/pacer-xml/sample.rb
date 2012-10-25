require 'set'

module PacerXml
  module Sample
    class << self
      def load(*args)
        i = importer(*args)
        i.run!
        i.graph
      end

      # Sample of using the xml import function with some advanced options to
      # clean up the resulting graph.
      #
      # Import can successfully be run with no options specified, but this patent
      # xml is particularly hairy.
      def importer(graph = nil, fn = nil, start_rule = nil, end_rule = nil)
        html = [:abstract]
        renames = {
          'classification-national' => 'classification',
          'assistant-examiner' => 'examiner',
          'primary-examiner' => 'examiner',
          'us-term-of-grant' => 'term',
          'addressbook' => 'entity',
          'document-id' => 'document',
          'us-related-documents' => 'related-document',
          'us-patent-grant' => 'patent-version',
          'us-bibliographic-data-grant' => 'patent'
        }
        cache = { stats: true }
        graph ||= Pacer.tg
        graph.create_key_index :type, :vertex
        xml_route = xml(fn, start_rule, end_rule)
        xml_route.
          process { print '.' }.
          import(graph, html: html, renames: renames, cache: cache)
      end

      def xml(fn = nil, *args)
        fn ||= a_week
        path = download_patent_grant fn
        Pacer.xml path, *args
      end

      def cleanup(fn = nil)
        fn ||= a_week
        name, week = fn.split '_'
        Dir["/tmp/#{name}*"].each { |f| File.delete f }
      end

      private

      def a_week
        'ipgb20120103_wk01'
      end

      def download_patent_grant(fn)
        puts "Downloading a sample xml file from"
        puts "http://www.google.com/googlebooks/uspto-patents-grants-biblio.html"
        name, week = fn.split '_'
        result = "/tmp/#{name}.xml"
        Dir.chdir '/tmp' do
          unless File.exists? result
            system "curl http://storage.googleapis.com/patents/grantbib/2012/#{fn}.zip > #{fn}.zip"
            system "unzip #{fn}.zip"
          end
        end
        result
      end
    end
  end
end
