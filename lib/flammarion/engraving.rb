module Flammarion
  class Engraving
    include Revelator
    include RecognizePath

    attr_accessor :on_disconnect, :on_connect, :sockets

    # Creates a new Engraving (i.e., a new display window)
    # @option options [Proc] :on_connect Called when the display window is
    #  connected (i.e., displayed)
    # @option options [Proc] :on_disconnect Called when the display windows is
    #  disconnected (i.e., closed)
    # @option options [Boolean] :exit_on_disconnect (false) Will call +exit+
    #  when the widow is closed if this option is true.
    # @option options [Boolean] :close_on_exit (false) Will close the window
    #  when the process exits if this is true. Otherwise, it will just stay
    #  around, but not actually be interactive.
    # @raise {SetupError} if neither chrome is set up correctly and
    #  and Flammarion is unable to display the engraving.
    def initialize(**options)
      @chrome = OpenStruct.new
      @sockets = []
      @on_connect = options[:on_connect]
      @on_disconnect = options[:on_disconnect]
      @exit_on_disconnect = options.fetch(:exit_on_disconnect, false)

      start_server
      @window_id = @@server.register_window(self)
      open_a_window(options) unless options[:no_window]
      wait_for_a_connection unless options[:no_wait]

      at_exit {close if window_open?} if options.fetch(:close_on_exit, true)
    end

    # Blocks the current thread until the window has been closed. All user
    # interactions and callbacks will continue in other threads.
    def wait_until_closed
      sleep 1 until @sockets.empty?
    end

    # Is this Engraving displayed on the screen.
    def window_open?
      !@sockets.empty?
    end

    def disconnect(ws)
      @sockets.delete ws
      exit 0 if @exit_on_disconnect
      @on_disconnect.call if @on_disconnect
    end

    def process_message(msg)
      params = JSON.parse(msg).with_indifferent_access
      action = params.delete(:action) || 'page'
      env = dispatch(params)

      send_json(action: action, html: env.last.body)

    rescue JSON::ParserError
      Rails.logger.debug "Invalid JSON String #{msg}"
    end

    def dispatch(params)
      http_method = (params[:method] ||= :get)
      params = recognize_path(params.delete(:url), params)

      unless params && params.key?(:controller)
        Rails.logger.debug "Path not found"
        return ActionDispatch::Request::PASS_NOT_FOUND.call(nil)
      end

      controller_name = "#{params.delete(:controller).underscore.camelize}Controller"
      controller      = ActiveSupport::Dependencies.constantize(controller_name)
      action          = params.delete(:action) || 'index'
      request         = ActionDispatch::Request.new('rack.input' => '', 'REQUEST_METHOD' => http_method.to_s.upcase!, 'action_dispatch.request.parameters' => params)
      response        = controller.make_response! request

      controller.dispatch(action, request, response)
    end

    def start_server
      @@server ||= Server.new
    end

    def server
      @@server
    end

    def send_json(val)
      if @sockets.empty?
        open_a_window
        wait_for_a_connection
      end
      @sockets.each{ |ws| ws.send val.to_json }
      nil
    end
  end
end
