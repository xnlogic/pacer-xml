module PacerXml
  unless const_defined? :VERSION
    START_TIME = Time.now
    VERSION = '0.1.1'
    PACER_VERSION = '>= 1.0'
  end
end
