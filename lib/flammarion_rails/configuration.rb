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
    attr_accessor :boot_path

    def boot_path
      @boot_path ||= '/'
    end
  end
end
