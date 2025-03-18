require "rspec"
require_relative "../ups_monitor"
require "json"
require "tempfile"

RSpec.describe UPSMonitor do
  let(:config_file) do
    Tempfile.new(["config", ".json"]).tap do |f|
      f.write(JSON.generate({
        qnap: {
          host: "192.168.1.100",
          username: "admin",
          ssh_key_path: "~/.ssh/qnap_key",
          mac_address: "00:11:22:33:44:55"
        },
        ups: {
          name: "AVR750U",
          low_battery_threshold: 20
        }
      }))
      f.flush
    end
  end

  let(:monitor) { UPSMonitor.new(config_file.path) }

  after do
    config_file.close
    config_file.unlink
  end

  describe "#load_config" do
    it "loads and parses the config file correctly" do
      config = monitor.load_config(config_file.path)
      expect(config[:qnap][:host]).to eq("192.168.1.100")
      expect(config[:ups][:name]).to eq("AVR750U")
      expect(config[:ups][:low_battery_threshold]).to eq(20)
    end

    it "expands the SSH key path" do
      config = monitor.load_config(config_file.path)
      expect(config[:qnap][:ssh_key_path]).to eq(File.expand_path("~/.ssh/qnap_key"))
    end
  end

  describe "#get_battery_info" do
    context "when UPS is on AC power" do
      before do
        allow(monitor).to receive(:`).with("pmset -g batt").and_return(
          "Now drawing from 'AC Power'\n" \
          "-InternalBattery-0 (id=34472035)\t100%; charged; 0:00 remaining present: true\n" \
          "-AVR750U          (id=716570624)\t100%; AC attached; not charging present: true"
        )
      end

      it "correctly parses UPS information" do
        info = monitor.get_battery_info
        expect(info[:battery_level]).to eq(100)
        expect(info[:ac_attached]).to be true
        expect(info[:present]).to be true
      end
    end

    context "when UPS is on battery power" do
      before do
        allow(monitor).to receive(:`).with("pmset -g batt").and_return(
          "Now drawing from 'Battery Power'\n" \
          "-InternalBattery-0 (id=34472035)\t100%; charged; 0:00 remaining present: true\n" \
          "-AVR750U          (id=716570624)\t75%; discharging present: true"
        )
      end

      it "correctly parses UPS information" do
        info = monitor.get_battery_info
        expect(info[:battery_level]).to eq(75)
        expect(info[:ac_attached]).to be false
        expect(info[:present]).to be true
      end
    end

    context "when UPS is not found" do
      before do
        allow(monitor).to receive(:`).with("pmset -g batt").and_return(
          "Now drawing from 'AC Power'\n" \
          "-InternalBattery-0 (id=34472035)\t100%; charged; 0:00 remaining present: true"
        )
      end

      it "returns nil" do
        expect(monitor.get_battery_info).to be_nil
      end
    end
  end

  describe "#check_power_status" do
    let(:ssh) { double("SSH") }

    context "when on AC power with good battery" do
      before do
        allow(monitor).to receive(:get_battery_info).and_return({
          battery_level: 100,
          ac_attached: true,
          present: true
        })
      end

      it "does not trigger any actions" do
        expect(monitor).not_to receive(:shutdown_qnap)
        expect(monitor).not_to receive(:wake_qnap)
        expect { monitor.check_power_status }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(0)
        end
      end
    end

    context "when on battery power below threshold" do
      before do
        allow(monitor).to receive(:get_battery_info).and_return({
          battery_level: 15,
          ac_attached: false,
          present: true
        })
      end

      it "triggers QNAP shutdown" do
        expect(monitor).to receive(:shutdown_qnap)
        expect { monitor.check_power_status }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(0)
        end
      end
    end
  end

  describe "#send_wol_packet" do
    let(:udp_socket) { instance_double(UDPSocket) }

    before do
      allow(UDPSocket).to receive(:new).and_return(udp_socket)
      allow(udp_socket).to receive(:setsockopt)
      allow(udp_socket).to receive(:close)
    end

    it "sends a properly formatted magic packet" do
      mac = "00:11:22:33:44:55"
      expected_packet = ([0xFF] * 6 +
                        [0x00, 0x11, 0x22, 0x33, 0x44, 0x55] * 16).pack("C*")

      expect(udp_socket).to receive(:send).with(expected_packet, 0, "255.255.255.255", 9)
      monitor.send(:send_wol_packet, mac)
    end
  end

  describe "#shutdown_qnap" do
    let(:ssh) { double("SSH") }

    it "executes shutdown command over SSH" do
      expect(Net::SSH).to receive(:start).with(
        "192.168.1.100",
        "admin",
        hash_including(
          keys: [File.expand_path("~/.ssh/qnap_key")],
          non_interactive: true
        )
      ).and_yield(ssh)

      expect(ssh).to receive(:exec!).with("shutdown -h now")
      monitor.shutdown_qnap
    end
  end
end
