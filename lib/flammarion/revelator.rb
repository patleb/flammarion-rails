module Flammarion
  class SetupError < StandardError; end

  module Revelator
    CHROME_PATH = ENV["FLAMMARION_REVELATOR_PATH"] || 'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe'

    def open_a_window(**options)
      index_path = FlammarionRails::Engine.root.join('public', 'index.html')
      index_path = `cygpath -w '#{index_path}'`.strip if RbConfig::CONFIG["host_os"] == "cygwin"

      url = "file://#{index_path}?" + { port: server.port, path: @window_id, boot: FlammarionRails.config.boot_path }.to_query
      @browser_options = options.merge(url: url)
      @requested_browser = ENV["FLAMMARION_BROWSER"] || options[:browser]

      @browser = @@browsers.find do |browser|
        next if @requested_browser and browser.name.to_s != @requested_browser
        begin
          send(browser.name, @browser_options)
        rescue Exception
          next
        end
      end

      raise SetupError.new("You must have google-chrome installed and accesible via your path.") unless @browser
    end

    def wait_for_a_connection
       Timeout.timeout(20) { sleep 0.5 while @sockets.empty? }
     rescue Timeout::Error
       raise SetupError.new("Timed out while waiting for a connecting using #{@browser.name}.")
    end

    private

    @@browsers = []

    def self.browser(name, &block)
      @@browsers << OpenStruct.new(name: name, method:define_method(name, block))
    end

    browser :osx do |options|
      return false unless RbConfig::CONFIG["host_os"] =~ /darwin|mac os/
      executable = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
      @chrome.in, @chrome.out, @chrome.err, @chrome.thread = Open3.popen3("'#{executable}' --app='#{options[:url]}'")
      true if @chrome.in
    end

    browser :chrome_windows do |options|
      return false unless RbConfig::CONFIG["host_os"] =~ /cygwin|mswin|mingw/
      file_path = File.absolute_path(File.join(File.dirname(__FILE__), ".."))
      file_path = `cygpath -w '#{file_path}'`.strip if RbConfig::CONFIG["host_os"] == "cygwin"
      resource = %[file\://#{file_path}/html/build/index.html]
      resource = "http://localhost:4567/" if options[:development_mode]
      chrome_path = CHROME_PATH
      chrome_path = `cygpath -u '#{CHROME_PATH}'`.strip if RbConfig::CONFIG["host_os"] == "cygwin"
      return false unless File.exist?(chrome_path)
      Process.detach(spawn(chrome_path, %[--app=#{resource}?path=#{@window_id}&port=#{server.port}]))
    end

    browser :chrome do |options|
      %w[google-chrome google-chrome-stable chromium chromium-browser chrome].each do |executable|
        next unless which(executable)
        @chrome.in, @chrome.out, @chrome.err, @chrome.thread = Open3.popen3("#{executable} --app='#{options[:url]}'")
        return true if @chrome.in
      end
      false
    end

    browser :www do |options|
      # Last ditch effort to display something
      Launchy.open(options[:url].gsub(/\s/, "%20")) do |error|
        return false
      end
      true
    end

    def which(cmd)
      exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
      ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
        exts.each do |ext|
          exe = File.join(path, "#{cmd}#{ext}")
          return exe if File.executable?(exe) && !File.directory?(exe)
        end
      end
      nil
    end
  end
end
