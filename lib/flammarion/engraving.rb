module Flammarion
  class Engraving
    include Revelator
    include RecognizePath

    attr_accessor :on_disconnect, :on_connect, :sockets, :request, :status, :headers, :response

    PROTOCOL = /^.*:\/{2}(:\d{0,4})?/i

    # Creates a new Engraving (i.e., a new display window)
    # @option options [Proc] :on_connect Called when the display window is
    #  connected (i.e., displayed)
    # @option options [Proc] :on_disconnect Called when the display windows is
    #  disconnected (i.e., closed)
    # @raise {SetupError} if chrome is not set up correctly and
    #  and Flammarion is unable to display the engraving.
    def initialize(**options)
      @chrome = OpenStruct.new
      @sockets = []
      @on_connect = options[:on_connect]
      @on_disconnect = options[:on_disconnect]

      start_server
      @window_id = @@server.register_window(self)
      open_a_window(options)
      wait_for_a_connection(options)
    end

    # Blocks the current thread until the window has been closed. All user
    # interactions and callbacks will continue in other threads.
    def wait_until_closed
      sleep 1 until @sockets.empty?
    end

    def disconnect(ws)
      @sockets.delete ws
      exit 0
      @on_disconnect.call if @on_disconnect
    end

    def process_message(msg)
      params = JSON.parse(msg).with_indifferent_access
      action = params.delete(:action) || 'page'
      dispatch(params)

      if status == 302
        dispatch(url: headers['Location'].sub(PROTOCOL, ''), session: response.request.session)
        render(action: 'page', body: response.body)
      elsif headers['Content-Transfer-Encoding'] == 'binary'
        filename = headers['Content-Disposition'].sub(/.*filename=/, '').gsub(/(^"|"$)/, '')
        render(action: 'file', name: filename)
        render(response.body)
        GC.start
      else
        render(action: action, body: response.body)
      end

    rescue => e
      Rails.logger.error "[EXCEPTION][#{msg}]"
      Rails.logger.error "  [#{e.class}]\n#{e.message}\n" << e.backtrace.first(20).join("\n")
      Rails.logger.error "[END]"
      render(action: 'error', title: "#{e.class}: #{e.message}")
    end

    def dispatch(params)
      session = params.delete(:session)
      url = params.delete(:url)
      uri = URI.parse(url)
      query_params = parse_nested_query(uri.query)

      request_params = {}
      if params.key?(:form)
        request_params = parse_nested_query(params.delete(:form))
        request_params[params.delete(:button)] = ''
        params[:method] = request_params[:_method] || 'post'
      end
      http_method = (params[:method] ||= :get).to_s.upcase!

      path_params = recognize_path(uri.path, params.merge!(query_params))
      unless path_params && path_params.key?(:controller)
        raise ActionController::RoutingError, "No route matches [#{http_method}] #{url}"
      end

      controller_name = "#{path_params[:controller].underscore.camelize}Controller"
      controller      = ActiveSupport::Dependencies.constantize(controller_name)
      action          = path_params[:action] || 'index'
      request_env     = {
        'rack.input' => '',
        'QUERY_STRING' => uri.query,
        'REQUEST_METHOD' => http_method,
        'REQUEST_PATH' => uri.path,
        'REQUEST_URI' => url,
        'PATH_INFO' => uri.path,
        'action_dispatch.request.query_parameters' => query_params,
        'action_dispatch.request.request_parameters' => request_params,
        'action_dispatch.request.path_parameters' => path_params,
        'action_dispatch.request.parameters' => params.merge!(request_params).merge!(path_params),
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
      if body.is_a? Hash
        body = body.to_json
      else
        binary = true
      end
      @sockets.each do |ws|
        ws.send_data(body, binary)
      end
    end

    def parse_nested_query(query)
      Rack::Utils.parse_nested_query(query).with_indifferent_access
    end
  end
end
