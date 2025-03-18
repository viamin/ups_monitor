# UPS Monitor for Network Attached Storage

This script monitors a UPS connected to a MacBook Pro and manages a Network Attached Storage (NAS) device based on power events. When the UPS battery level gets too low, it safely shuts down the NAS. When power is restored, it automatically wakes the NAS using Wake-on-LAN.

## Features

- Monitors UPS battery level using macOS `pmset`
- Automatically shuts down NAS when UPS battery is low
- Wakes NAS using Wake-on-LAN when power is restored
- Uses secure SSH key authentication
- Runs as a LaunchAgent for automatic startup
- Comprehensive logging

## Prerequisites

- macOS (tested on macOS Sequoia 15.3.2)
- Ruby 3.2.2
- A NAS with:
  - SSH enabled
  - Wake-on-LAN enabled in BIOS/UEFI
  - Network configuration that allows Wake-on-LAN packets

## Installation

1. Clone this repository:

   ```bash
   git clone <repository-url>
   cd ups_monitor
   ```

2. Install required gems:

   ```bash
   bundle install
   ```

3. Generate an SSH key for NAS authentication:

   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/nas_key -C "ups_monitor"
   ```

4. Copy the SSH public key to your NAS:

   ```bash
   ssh-copy-id -i ~/.ssh/nas_key.pub admin@your-nas-ip
   ```

5. Configure the script (see Configuration section below)

6. Install the LaunchAgent:

   ```bash
   cp com.ups.monitor.plist ~/Library/LaunchAgents/
   launchctl load ~/Library/LaunchAgents/com.ups.monitor.plist
   ```

## Configuration

Copy the example configuration file and edit it with your settings:

```bash
cp config.json.example config.json
```

Edit `config.json` with your NAS details:

```json
{
  "nas": {
    "host": "192.168.1.100",        # Your NAS's IP address
    "username": "admin",            # Your NAS SSH username
    "ssh_key_path": "~/.ssh/nas_key",  # Path to SSH private key
    "mac_address": "00:11:22:33:44:55"  # Your NAS's MAC address
  },
  "ups": {
    "name": "AVR750U",             # Your UPS model name from pmset
    "low_battery_threshold": 20     # Battery percentage to trigger shutdown
  }
}
```

### Finding Your UPS Name

To find your UPS name, run:

```bash
pmset -g batt
```

Look for a line containing your UPS model, for example:

```plaintext
-AVR750U (id=123456789) 100%; AC attached; not charging present: true
```

### Finding Your NAS's MAC Address

1. Log into your NAS's web interface
2. Check your network interface settings or system information
3. Look for "MAC Address" or "Physical Address"

## Usage

The script will start automatically after installing the LaunchAgent. You can manually control it using:

```bash
# Start the monitor
launchctl start com.ups.monitor

# Stop the monitor
launchctl stop com.ups.monitor

# Check status
launchctl list | grep com.ups.monitor
```

### Logs

The script creates several log files:

- `ups_monitor.log`: Main application log
- `ups_monitor.out.log`: Standard output log
- `ups_monitor.err.log`: Error log

These files are located in the script's directory.

## Testing

To test the setup:

1. Verify SSH key authentication:

   ```bash
   ssh -i ~/.ssh/nas_key admin@your-nas-ip
   ```

2. Check UPS monitoring:

   ```bash
   ruby ups_monitor.rb
   ```

   (Press Ctrl+C to stop)

3. Check the logs:

   ```bash
   tail -f ups_monitor.log
   ```

## Troubleshooting

1. **SSH Connection Issues**
   - Verify SSH is enabled on your NAS
   - Check SSH key permissions (should be 600)
   - Test SSH connection manually

2. **Wake-on-LAN Issues**
   - Verify Wake-on-LAN is enabled in NAS BIOS/UEFI
   - Check network allows broadcast packets
   - Verify MAC address is correct

3. **UPS Not Detected**
   - Check UPS name in config matches `pmset -g batt` output
   - Verify UPS is connected and recognized by macOS
