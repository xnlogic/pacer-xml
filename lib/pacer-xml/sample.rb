module PacerXml
  module Sample
    class << self
      def a_week
        'ipgb20120103_wk01'
      end

      def download_patent_grant(fn)
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

      def cleanup(fn)
        name, week = fn.split '_'
        Dir["/tmp/#{name}*"].each { |f| File.delete f }
      end

      def xml(fn = nil)
        fn ||= a_week
        path = download_patent_grant fn
        Pacer.xml path
      end
    end
  end
end
