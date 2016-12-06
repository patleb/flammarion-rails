module Flammarion
  class Server
    attr_accessor :port

    def initialize
      @windows = {}
      @socket_paths = {}
      @started = false
      @launch_thread = Thread.current
      @server_thread = Thread.new do
        begin
          start_server_internal
        rescue StandardError => e
          handle_exception(e)
        end
      end
      sleep 0.5 until @started
    end

    def start_server_internal
      self.port =
        if Gem.win_platform?
          rand(65000 - 1024) + 1024
        else
          7870
        end
      begin
        @server = Rubame::Server.new("0.0.0.0", port)
        loop do
          @started = true
          @server.run do |ws|
            ws.onopen {
              log "Connection open"
              if @windows.include?(ws.handshake.path)
                @windows[ws.handshake.path].sockets << ws
                @windows[ws.handshake.path].on_connect.call if @windows[ws.handshake.path].on_connect
                @socket_paths[ws] = ws.handshake.path
              else
                log "No such window: #{handshake.path}"
              end
            }

            ws.onclose do
              log "Connection closed"
              @windows[@socket_paths[ws]].disconnect(ws) if @windows[@socket_paths[ws]]
            end

            ws.onmessage { |msg|
              Thread.new do
                begin
                  @windows[@socket_paths[ws]].process_message(msg)
                rescue StandardError => e
                  handle_exception(e)
                end
              end
            }
          end
        end
      rescue RuntimeError, Errno::EADDRINUSE => e
        if e.message == "no acceptor (port is in use or requires root privileges)" || e.is_a?(Errno::EADDRINUSE)
          self.port = rand(65000 - 1024) + 1024
          retry
        else
          raise
        end
      end
      @started = true
    end

    def stop
    end

    def log(str)
      Rails.logger.debug str
    end

    def handle_exception(e)
      @launch_thread.raise(e)
    end

    def register_window(window)
      @new_path ||= 0
      @new_path += 1
      @windows["/w#{@new_path}"] = window
      "w#{@new_path}"
    end
  end
end
