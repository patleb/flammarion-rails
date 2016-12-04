module FlammarionRails
  @@config = nil

  def self.configure
    @@config ||= Configuration.new

    if block_given?
      yield config
    end

    config
  end

  def self.config
    @@config || configure
  end

  class Configuration
    # attr_writer :config_name
    # attr_accessor :other_config_name

    # def config_name
    #   @config_name ||= 'default value'
    # end
  end
end
