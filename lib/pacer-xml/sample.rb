require 'set'

module PacerXml
  module Sample
    class << self
      # Will actually load 101. To avoid this side-effect of
      # prefetching, the route should be defined as:
      # xml_route.limit(100).import(...)
      def load_100(*args, &block)
        i = importer(*args, &block).limit(100)
        i.run!
        i.graph
      end

      def load_100_with_text(graph = nil, args = {}, &block)
        load_100 graph, args.merge(source: :full_text), &block
      end

      def load_all_with_text(graph = nil, args = {}, &block)
        load_all graph, args.merge(source: :full_text), &block
      end

      def load_all_software(*args)
        load_all_with_text(*args) do |xml_documents|
          xml_documents.select do |raw_xml|
            raw_xml =~ /software/i
          end
        end
      end

      def load_100_software(*args)
        load_100_with_text(*args) do |xml_documents|
          xml_documents.select do |raw_xml|
            raw_xml =~ /software/i
          end
        end
      end

      # Uses a Neo4j graph because the data is too big to fit in memory
      # without configuring the JVM to use more than its small default
      # footprint.
      #
      # Alternatively, To start the JVM with more memory, try:
      # bundle exec jruby -J-Xmx2g -S irb
      def load_all(graph = nil, args = {}, &block)
        require 'pacer-neo4j'
        n = Time.now.to_i % 1000000
        graph ||= Pacer.neo4j "sample.#{n}.graph"
        i = importer(graph, args, &block)
        if args[:thread]
          t = Thread.new do
            begin
              i.run!
            rescue Exception => e
              pp e
              pp e.backtrace
            end
          end
          t[:graph] = graph
          t
        else
          i
        end
      end

      def structure(g)
        Pacer::Utils::GraphAnalysis.structure g
      end

      def structure!(g, fn = 'patent-structure.graphml')
        s = structure g
        if fn
          e = Pacer::Utils::YFilesExport.new
          e.vertex_label = s.vertex_name
          e.edge_label = s.edge_name
          e.export s, fn
          puts
          puts "Wrote #{ fn }"
        end
        s
      end

      # Sample of using the xml import function with some advanced options to
      # clean up the resulting graph.
      #
      # Import can successfully be run with no options specified, but this patent
      # xml is particularly hairy.
      def importer(graph = nil, args = {}, &block)
        html = [:abstract, :description]
        with_body = ['claim-text']
        rename = {
          'classification-national' => 'class',
          'assistant-examiner' => 'examiner',
          'primary-examiner' => 'examiner',
          'us-term-of-grant' => 'term',
          'addressbook' => 'entity',
          'document-id' => 'document',
          'us-related-documents' => 'related-document',
          'us-patent-grant' => 'patent-version',
          'us-bibliographic-data-grant' => 'patent',
          "us-field-of-classification-search" => 'possible-class'
        }
        skip = Set['classification-ipcr']
        skip_cache = Set['figures', 'figure']
        cache = { stats: true, skip: skip_cache }.merge(args.fetch(:cache, {}))
        graph ||= Pacer.tg
        graph.create_key_index :type, :vertex
        start_time = Time.now
        n = 0
        xml_route = xml(args, &block)
        unless args[:silent]
          xml_route = xml_route.process do
            n += 1
            puts "\n       #{ n } patents in #{ Time.now - start_time }s" if n % 100 == 0
          end
        end
        xml_route.import(graph, html: html, skip: skip, rename: rename, cache: cache, with_body: with_body)
      end

      def xml(args, &block)
        path = download_patent_grant args
        Pacer.xml path, args[:start_chunk_rule], args[:end_chunk_rule], &block
      end

      def cleanup(fn = nil)
        fn ||= a_week
        name, week = fn.split '_'
        Dir["/tmp/#{name}*"].each { |f| File.delete f }
      end

      def path(args)
        if args[:path]
          args[:path]
        else
          "/tmp/#{patent_file(args).sub(/_wk\d+/, '')}.xml"
        end
      end

      def url(args)
        if args[:url]
          args[:url]
        elsif args[:path]
          nil
        elsif args[:source] == :full_text
          "http://storage.googleapis.com/patents/grant_full_text/#{patent_year(args)}/#{patent_file(args)}.zip"
        else
          "http://storage.googleapis.com/patents/grantbib/#{patent_year(args)}/#{patent_file(args)}.zip"
        end
      end

      private

      def patent_date(args)
        args.fetch :date, Date.parse('20120103')
      end

      def patent_file(args)
        if args[:source] == :full_text
          date = patent_date(args).strftime "%y%m%d"
          file = "ipg#{date}"
        else
          date = patent_date(args).strftime "%Y%m%d_wk%V"
          file = "ipgb#{date}"
        end
      end

      def patent_year(args)
        patent_date(args).year
      end

      def download_patent_grant(args)
        location = url(args)
        result = path(args)
        unless File.exists? result
          if location
            puts "Downloading a sample xml file from"
            puts "http://www.google.com/googlebooks/uspto-patents-grants-biblio.html"
            puts location
            Dir.chdir '/tmp' do
              system "curl #{location} > #{result}.zip"
              system "unzip #{result}.zip"
            end
          else
            throw "File not found"
          end
        end
        result
      end
    end
  end
end
