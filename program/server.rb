require 'socket'
require 'base62'
# For escaping URIs
require 'uri'

$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'packet'
require 'player'
require "zlib"

class Server
  Config_Template = "name = MCRuby Default Server
port = 25565
public = True
maxplayers = 24"
  Properties_Template = "heartbeat_interval = 30"

  def initialize
    @cfg = map_config("server.properties", Properties_Template)
    @salt = rand_base_62(16)
    @players = []
  end

# Create the file if it doesn't already exist, then return
# the contents
  def load_config(fname, template)
    unless File.exist?(fname)
      # Create the file
      File.open(fname, "wb") { |f| f.print(template.to_s) }
      # We don't actually read the file since we know what's in it
      return template
    end
    # Read the entire file
    File.open(fname, "rb") { |f| return f.readlines.join }
  end

# Maps the config file to a hashmap, e.g. this:
#  foo = hello
#  bar = world
# becomes:
#  {"foo"=>"hello", "bar"=>"world"}
  def map_config(*args)
    pairs = load_config(*args).split("\n")
    result = {}
    pairs.each { |raw|
      key, val = raw.split(" = ")
      result[key] = val
    }
    result
  end

  def rand_base_62(length)
    result = ""
    numset = ([0..9, "a".."z", "A".."Z"].collect { |char| char.to_a }).flatten
    length.times {
      result << numset.sample.to_s
    }
    result
  end

# Returns a string of URL parameters (loaded from server.config)
# with the argument extras added
  def param_str(extras=[])
    result = []
    needed_vals = ["name", "port", "public", "max"]
    props = map_config("server.properties", Config_Template)
    needed_vals.each {|v|
      result << "#{URI.encode_www_form_component(v)}=#{URI.encode_www_form_component(props[v])}"
    }
    result += extras
    result.join("&")
  end

  def send_heartbeat
    hb_host = "www.classicube.net"
    port = 80
    # Parameters that can't be found in the config file
    params = param_str(["salt=#{@salt}", "version=7", "users=0", "software=MCRuby"])
    hb_page = "/heartbeat.jsp?#{params}"
    @last_url = hb_host + hb_page
    # POST requests also worlk
    request = "GET #{hb_page} HTTP/1.0\r\nHost:www.classicube.net\r\n\r\n"
    # Open a connection
    hbsocket = TCPSocket.open(hb_host, port)
    # Register the server
    hbsocket.print(request)
    # Return classicube.net's response (should be the url to this
    # server in plain text)
    hbsocket.read.split("\r\n\r\n", 2).last
  end

  def stringify(str)
    if str.nil?
      str = ''
    end
    str = str.ljust(64, ' ')
  end

  def start_handle_connections
    # Start listening
    @listener = TCPServer.new("127.0.0.1", 25565)
    Thread.fork do
      loop do
        Thread.start(@listener.accept) do |client|
          n, m = stringify(@cfg["name"]), stringify(@cfg["motd"])
          # It appears that you need to send a server ID packet before the client sends anything over?
          client.write "\x00\x07#{n}#{m}\x64"
          puts 'Server identified'

          client.write "\x01"
          puts 'Pinged client'

          client.write "\x02"
          puts 'Level initialized'

          #File.open(replay_file) do |file|
            #first_portion = file.read(20)
            #file.seek(24, IO::SEEK_END)
            #second_portion = file.read(20)
          #end

          # Get data chunks of level?
          Zlib::GzipReader.open('main.lvl') {|lvl|
            identifier = lvl.read | (lvl.read << 8)

            width = lvl.read | (lvl.read << 8)
            length = lvl.read | (lvl.read << 8)
            height = lvl.read | (lvl.read << 8)
            spawn_x = lvl.read | (lvl.read << 8)
            spawn_z = lvl.read | (lvl.read << 8)
            spawn_y = lvl.read | (lvl.read << 8)
            spawn_yaw = lvl.read
            spawn_pitch = lvl.read
            #read() # pervisit, useless
            #read() # perbuild, useless
            blocks = read(width * height * length)
            print blocks
          }

          client.write "\x03" # ??

          x = 128
          y = 128
          z = 128

          client.write "\x04#{x}#{y}#{z}"
          puts 'Level finalized'

          # Receive the "join packet" from the player (http://www.minecraftwiki.net/wiki/Classic_server_protocol#Client_.E2.86.92_Server_packets)
          d = client.read
          puts d
          # client.close()
        end
      end
    end
  end

  # Not threaded
  def start
    resp = send_heartbeat
    unless resp[0..6] == "http://"
      puts "Got unexpected response from https://classicube.net/heartbeat.jsp!"
      puts "-- DEBUG --"
      puts "Expected URL but got this from #{@last_url}:"
      puts resp
      puts "-- END DEBUG --"
    end
    start_handle_connections
    puts "Server up! You can connect to this server in an internet browser via `#{resp}'."
    loop do
      sleep(@cfg["heartbeat_interval"].to_i)
      send_heartbeat
    end
  end
end
