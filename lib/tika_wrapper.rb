require 'tika_wrapper/version'
require 'tika_wrapper/instance'

module TikaWrapper
  def self.default_tika_version
    "1.8"
  end

  def self.default_instance(options = {})
    @default_instance ||= TikaWrapper::Instance.new options
  end

  ##
  # Ensures a tika service is running before executing the block
  def self.wrap(options = {}, &block)
    default_instance(options).wrap(&block)
  end
end
