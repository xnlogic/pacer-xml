module PacerXml
  unless const_defined? :VERSION
    START_TIME = Time.now
    VERSION = '0.2.3'
    PACER_VERSION = '>= 1.1.1'
  end
end
