module PacerXml
  unless const_defined? :VERSION
    START_TIME = Time.now
    VERSION = '0.1.0'
    PACER_VERSION = '>= 1.1.0'
  end
end
