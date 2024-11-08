### README.md

# Xray Installation and Management Script

This script automates the installation, configuration, and management of Xray on a Linux system. It helps in setting up Xray as a proxy server, with options for WebSocket, TLS encryption, and UUID generation. It also provides options for managing the Xray service, modifying the configuration, and viewing runtime logs.

## Features

- **Install Xray**: Automatically installs Xray-core on your Linux server.
- **WebSocket Support**: Optionally enable WebSocket for Xray.
- **TLS Encryption**: Optionally enable TLS encryption with custom certificates.
- **UUID Generation**: Generates a new UUID for client authentication.
- **Port Modification**: Change the port Xray listens on.
- **Service Management**: Start, stop, restart, and enable/disable Xray service using systemd.
- **Client Information**: View real-time logs, connected clients, and their geographic location based on IP.
- **Configuration Management**: View and modify the Xray configuration.

## Requirements

- A Linux server with `apt` package manager (e.g., Ubuntu/Debian).
- Root privileges to install software and manage services.
- Internet connection to download Xray and required components.

## Usage

1. **Install Xray**:  
   Run the script and select `1` to install Xray.
   ```
   ./xray-install.sh
   ```

2. **Uninstall Xray**:  
   To remove Xray, select `2` from the main menu.

3. **Modify Configuration**:  
   You can modify the port or UUID by selecting options `3` and `4`.

4. **View Connected Clients**:  
   Select `7` to view the connected clients and their geographical information.

5. **Start, Stop, or Restart Xray**:  
   You can manage the Xray service with the options `9`, `10`, or `11`.

## Configuration Options

- **Port**: The script prompts you to enter the port Xray will listen on (default: 1080).
- **WebSocket**: Optionally enable WebSocket support by answering "y" when prompted.
- **TLS Encryption**: Enable TLS encryption by providing a domain name and paths to your TLS certificate and private key.

## License

This project is open source and available under the **MIT License**.
