module Flammarion
  class Engraving
    include Revelator
    include RecognizePath

    attr_accessor :on_disconnect, :on_connect, :sockets, :request, :status, :headers, :response

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
      @processing = false

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
      if @processing
        return render(action: 'error', title: 'Processing...')
      end
      @processing = true

      params = JSON.parse(msg).with_indifferent_access
      action = params.delete(:action) || 'page'
      dispatch(params)

      if status == 302
        params = {
          url: headers['Location'].sub(/^.*:\/{2}(:\d{0,4})?/i, ''),
          session: response.request.session
        }.with_indifferent_access
        dispatch(params)
        render(action: 'page', html: response.body)
      elsif headers['Content-Transfer-Encoding'] == 'binary'
        filename = headers['Content-Disposition'].sub(/.*filename=/, '').gsub(/(^"|"$)/, '')
        render(action: 'file', name: filename)
        render(response.body)
      else
        render(action: action, html: response.body)
      end

    rescue => e
      Rails.logger.error "[EXCEPTION][#{msg}]"
      Rails.logger.error "  [#{e.class}]\n#{e.message}\n" << e.backtrace.first(20).join("\n")
      Rails.logger.error "[END]"
      render(action: 'error', title: "#{e.class}: #{e.message}")
    ensure
      @processing = false
    end

    def dispatch(params)
      session = params.delete(:session)
      url = params.delete(:url)
      uri = URI.parse(url)
      query_params = Rack::Utils.parse_nested_query(uri.query)

      if params.key?(:form)
        params[:method] = 'post'
        params[params.delete(:button)] = ''
        params.merge!(Rack::Utils.parse_nested_query(params.delete(:form)))
      end
      if params.key?(:_method)
        params[:method] = params[:_method]
      end
      params[:method] ||= :get

      path_params = recognize_path(url, params)
      unless path_params.key?(:controller)
        raise ActionController::RoutingError, "No route matches [#{url}]#{params.inspect}"
      end

      controller_name = "#{path_params[:controller].underscore.camelize}Controller"
      controller      = ActiveSupport::Dependencies.constantize(controller_name)
      action          = path_params[:action] || 'index'
      request_env     = {
        'rack.input' => '',
        'REQUEST_METHOD' => params[:method].to_s.upcase,
        'action_dispatch.request.parameters' => path_params.merge!(params).merge!(query_params),
      }
      request_env['rack.session'] = session if session
      self.request    = ActionDispatch::Request.new(request_env)
      response        = controller.make_response! request

      self.status, self.headers, body = controller.dispatch(action, request, response)
      self.response = body.instance_variable_get(:@response)
    end

    def start_server
      @@server ||= Server.new
    end

    def server
      @@server
    end

    def render(body)
      if @sockets.empty?
        open_a_window
        wait_for_a_connection
      end
      if body.is_a? Hash
        body = body.to_json
      else
        binary = true
      end
      @sockets.each do |ws|
        ws.send_data(body, binary)
      end
      nil
    end
  end
end
