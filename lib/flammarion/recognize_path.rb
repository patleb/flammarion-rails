module Flammarion
  module RecognizePath
    def recognize_path(path, options)
      recognized_path = Rails.application.routes.recognize_path(path, options)

    rescue ActionController::RoutingError => e
      unless e.message.start_with? 'No route matches'
        raise e
      end

      Rails::Engine.subclasses.each do |engine|
        mounted_engine = Rails.application.routes.routes.find{ |r| r.app.app == engine }
        next unless mounted_engine

        path_for_engine = path.sub(/^#{mounted_engine.path.spec}/, '')
        begin
          recognized_path = engine.routes.recognize_path(path_for_engine, options)
          break
        rescue ActionController::RoutingError => e
          # do nothing
        end
      end

      recognized_path
    end
  end
end
