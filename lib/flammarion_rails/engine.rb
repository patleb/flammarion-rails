require "flammarion_rails/configuration"

module FlammarionRails
  class Engine < ::Rails::Engine
    # Initialize engine dependencies on wrapper application
    Gem.loaded_specs["flammarion_rails"].dependencies.each do |d|
      begin
        require d.name
      rescue LoadError => e
        # Put exceptions here.
      end
    end
    # Uncomment if migrations need to be shared
    # initializer :append_migrations do |app|
    #   unless app.root.to_s.match root.to_s
    #     config.paths["db/migrate"].expanded.each do |expanded_path|
    #       app.config.paths["db/migrate"] << expanded_path
    #     end
    #   end
    # end
  end
end
