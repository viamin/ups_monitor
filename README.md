# UPS Monitor for QNAP NAS

This script monitors a UPS connected to a MacBook Pro and manages a QNAP NAS based on power events. When the UPS battery level gets too low, it safely shuts down the QNAP. When power is restored, it automatically wakes the QNAP using Wake-on-LAN.

## Features

- Monitors UPS battery level using macOS `pmset`
- Automatically shuts down QNAP NAS when UPS battery is low
- Wakes QNAP using Wake-on-LAN when power is restored
- Uses secure SSH key authentication
- Runs as a LaunchAgent for automatic startup
- Comprehensive logging

## Prerequisites

- macOS (tested on macOS Sonoma 24.3.0)
- Ruby 2.6 or higher
- A QNAP NAS with:
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

3. Generate an SSH key for QNAP authentication:
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/qnap_key -C "ups_monitor"
   ```

4. Copy the SSH public key to your QNAP:
   ```bash
   ssh-copy-id -i ~/.ssh/qnap_key.pub admin@your-qnap-ip
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

Edit `config.json` with your QNAP details:

```json
{
  "qnap": {
    "host": "192.168.1.100",        # Your QNAP's IP address
    "username": "admin",            # Your QNAP SSH username
    "ssh_key_path": "~/.ssh/qnap_key",  # Path to SSH private key
    "mac_address": "00:11:22:33:44:55"  # Your QNAP's MAC address
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
```
-AVR750U (id=716570624) 100%; AC attached; not charging present: true
```

### Finding Your QNAP's MAC Address

1. Log into your QNAP's web interface
2. Go to Control Panel → System → System Status
3. Look for "LAN MAC Address" or check your network interface settings

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
   ssh -i ~/.ssh/qnap_key admin@your-qnap-ip
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
   - Verify SSH is enabled on your QNAP
   - Check SSH key permissions (should be 600)
   - Test SSH connection manually

2. **Wake-on-LAN Issues**
   - Verify Wake-on-LAN is enabled in QNAP BIOS
   - Check network allows broadcast packets
   - Verify MAC address is correct

3. **UPS Not Detected**
   - Check UPS name in config matches `pmset -g batt` output
   - Verify UPS is connected and recognized by macOS

## Security Notes

- The script uses SSH key authentication for secure access
- No passwords are stored in configuration files
- All sensitive operations are logged
- The LaunchAgent runs under user context, not root

## Contributing

Feel free to submit issues and pull requests.

## License

[Your chosen license]