module Rubame
  class Server
    def initialize(host, port)
      Socket.do_not_reverse_lookup
      @hostname = host
      @port = port

      @reading = []
      @writing = []

      @clients = {} # Socket as key, and Client as value

      @socket = TCPServer.new(@hostname, @port)
      @reading.push @socket
    end

    def accept
      socket = @socket.accept_nonblock
      @reading.push socket
      handshake = WebSocket::Handshake::Server.new
      client = Rubame::Client.new(socket, handshake, self)
      
      while (line = socket.gets)
        client.handshake << line
        break if client.handshake.finished?
      end

      if client.handshake.valid?
        @clients[socket] = client
        client.write handshake.to_s
        client.opened = true
        return client
      else
        close(client)
      end

      nil
    end

    def read(client)
      pairs = client.socket.recvfrom(2000)
      messages = []

      if pairs[0].length == 0
        close(client)
      else
        client.frame << pairs[0]

        while (f = client.frame.next)
          if f.type == :close
            close(client)
            return messages
          else
            messages.push f
          end
        end
      end

      messages
    end

    def close(client)
      @reading.delete client.socket
      @clients.delete client.socket
      client.socket.close
    rescue
      # do nothing
    ensure
      client.closed = true
    end

    def run(&blk)
      readable, _writable = IO.select(@reading, @writing)

      if readable
        readable.each do |socket|
          client = @clients[socket]
          if socket == @socket
            client = accept
          else
            msg = read(client)
            client.messaged = msg
          end

          blk.call(client) if client && blk
        end
      end
    end

    def stop
      @socket.close
    end
  end

  class Client
    attr_accessor :socket, :handshake, :frame, :opened, :messaged, :closed

    def initialize(socket, handshake, server)
      @socket = socket
      @handshake = handshake
      @frame = WebSocket::Frame::Incoming::Server.new(version: @handshake.version)
      @opened = false
      @messaged = []
      @closed = false
      @server = server
    end

    def write(data)
      @socket.write data
    end

    def send_data(data, binary = false)
      type = binary ? :binary : :text
      frame = WebSocket::Frame::Outgoing::Server.new(version: @handshake.version, data: data, type: type)
      @socket.write frame
      @socket.flush
    rescue
      @server.close(self) unless @closed
    end

    def onopen(&blk)
      return unless @opened
      blk.call
    ensure
      @opened = false
    end

    def onmessage(&blk)
      @messaged.each do |x|
        blk.call(x.to_s)
      end
    ensure
      @messaged = []
    end

    def onclose(&blk)
      return unless @closed
      blk.call
    ensure
      # do nothing
    end
  end
end

if __FILE__==$0
  server = Rubame::Server.new("0.0.0.0", 25222)
  while !$quit
    server.run do |client|
      client.onopen do
        puts "Server reports:  client open"
      end
      client.onmessage do |mess|
        puts "Server reports:  message received: #{mess}"
      end
      client.onclose do
        puts "Server reports:  client closed"
      end
    end
  end
end
