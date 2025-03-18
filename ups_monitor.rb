#!/usr/bin/env ruby

require "net/ssh"
require "logger"
require "json"
require "socket"

class UPSMonitor
  def initialize(config_path = "config.json")
    @config = load_config(config_path)
    @logger = setup_logger
    @last_power_state = get_last_power_state
  end

  def load_config(config_path)
    config = JSON.parse(File.read(config_path))
    {
      qnap: {
        host: config["qnap"]["host"],
        username: config["qnap"]["username"],
        ssh_key_path: File.expand_path(config["qnap"]["ssh_key_path"]),
        mac_address: config["qnap"]["mac_address"]
      },
      ups: {
        name: config["ups"]["name"],
        low_battery_threshold: config["ups"]["low_battery_threshold"]
      }
    }
  end

  def setup_logger
    logger = Logger.new("ups_monitor.log")
    logger.level = Logger::INFO
    logger.formatter = proc do |severity, datetime, progname, msg|
      "#{datetime.strftime("%Y-%m-%d %H:%M:%S")} [#{severity}] #{msg}\n"
    end
    logger
  end

  def get_battery_info
    output = `pmset -g batt`
    ups_line = output.lines.find { |line| line.include?(@config[:ups][:name]) }
    return nil unless ups_line

    {
      battery_level: ups_line.match(/(\d+)%/)[1].to_i,
      ac_attached: ups_line.include?("AC attached"),
      present: ups_line.include?("present: true")
    }
  end

  def get_last_power_state
    return nil unless File.exist?("last_state.txt")
    begin
      File.read("last_state.txt").strip.to_sym
    rescue
      nil
    end
  end

  def save_power_state(state)
    File.write("last_state.txt", state.to_s)
  end

  def check_power_status
    battery_info = get_battery_info
    return unless battery_info

    current_state = battery_info[:ac_attached] ? :ac : :battery

    if current_state != @last_power_state
      handle_power_state_change(current_state)
      save_power_state(current_state)
    end

    if current_state == :battery && battery_info[:battery_level] <= @config[:ups][:low_battery_threshold]
      shutdown_qnap
      exit(0)
    end

    # Exit with different status codes to indicate state
    if current_state == :ac && battery_info[:battery_level] > @config[:ups][:low_battery_threshold]
      exit(0)  # Normal state, AC power and good battery
    else
      exit(1)  # Abnormal state, either on battery or low battery
    end
  end

  def handle_power_state_change(new_state)
    @logger.info("Power state changed from #{@last_power_state} to #{new_state}")

    if new_state == :ac && @last_power_state == :battery
      wake_qnap
    end
  end

  def shutdown_qnap
    @logger.info("Initiating QNAP shutdown")
    begin
      Net::SSH.start(
        @config[:qnap][:host],
        @config[:qnap][:username],
        keys: [@config[:qnap][:ssh_key_path]],
        non_interactive: true
      ) do |ssh|
        ssh.exec!("shutdown -h now")
      end
      @logger.info("QNAP shutdown command sent successfully")
    rescue => e
      @logger.error("Failed to shutdown QNAP: #{e.message}")
    end
  end

  def wake_qnap
    @logger.info("Attempting to wake QNAP")
    begin
      send_wol_packet(@config[:qnap][:mac_address])
      @logger.info("Wake-on-LAN packet sent successfully")
    rescue => e
      @logger.error("Failed to send Wake-on-LAN packet: #{e.message}")
    end
  end

  private

  def send_wol_packet(mac_address)
    # Clean up MAC address format
    mac_bytes = mac_address.split(":").map { |h| h.to_i(16).chr }.join

    # Create magic packet
    magic_packet = [0xFF].pack("C") * 6 + mac_bytes * 16

    # Send packet using UDP broadcast
    socket = UDPSocket.new
    socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
    socket.send(magic_packet, 0, "255.255.255.255", 9)
    socket.close
  end

  def run
    @logger.info("Running UPS status check")
    check_power_status
  end
end

if __FILE__ == $PROGRAM_NAME
  monitor = UPSMonitor.new
  monitor.run
end
