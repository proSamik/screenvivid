![ScreenVivid](./assets/banner.svg)

<br>
<br>

ScreenVivid is a powerful and user-friendly screen recording application that allows you to capture your screen and enhance your recordings with intuitive editing features.
## Table of Contents

- [Features](#features)
- [Installation Guide](#installation-guide)
  - [System Requirements](#system-requirements)
  - [Linux Installation](#linux-installation)
  - [Windows Installation](#windows-installation)
  - [Troubleshooting Installation](#troubleshooting-installation)
- [Usage](#usage)
- [Advantages](#advantages)
- [Current Limitations](#current-limitations)
- [Roadmap](#roadmap)
- [Support](#support)
- [License](#license)

## Features

- Screen recording with high quality output
- Video enhancement tools (backgrounds, padding, etc.)
- User-friendly interface
- Cross-platform support (Ubuntu/Debian and Windows)

## Installation Guide

### System Requirements

- **Ubuntu/Debian**:
  - The app is based on PySide6, which requires glibc-2.28+. It supports Ubuntu 20.04 or later, and Debian 10 or later.
  - 4GB RAM (8GB recommended)
- **Windows**:
  - Windows 10 or later
  - 4GB RAM (8GB recommended)

### Linux Installation

1. Install system dependecies if needed:
   ```bash
   # Ubuntu/Debian
   sudo apt install curl git python3-tk python3-dev libxcb-cursor-dev -y

   # Fedora/CentOS
   sudo yum install
   ```

2. Install:

   ```bash
   curl -sL https://github.com/tamnguyenvan/screenvivid/raw/main/install.sh | bash
   ```

### Windows Installation

1. Download the latest .exe installer from our official website.

2. Right-click the downloaded file and select "Run as administrator".

3. Follow the installation wizard:
   - Choose installation directory
   - Select start menu folder
   - Choose additional tasks (create desktop shortcut, etc.)

4. Click "Install" and wait for the process to complete.

5. Launch ScreenVivid from the Start menu or desktop shortcut.

### Troubleshooting Installation

- **Ubuntu/Debian**:
  - If you see "dependency problems", try:
    ```
    sudo apt-get install -f
    ```
  - For "permission denied" errors, ensure you're using `sudo`.

- **Windows**:
  - If the installer doesn't run, right-click and select "Run as administrator".
  - For "Windows protected your PC" message, click "More info" then "Run anyway".

- For any other issues, please check our [FAQ](https://screenvivid.com/faq) or [contact support](#support).

## Usage

1. Launch ScreenVivid from your applications menu or start menu.
2. Click the "Record" button to start capturing your screen.
3. Use the editing tools to enhance your recording after capture.
4. Save your edited video in your preferred format.

## Advantages

- Easy to use
- Cross-platform
- Intuitive and simple interface
- Completely free
- Lightweight and fast

## Current Limitations

- Advanced features like zoom, audio capture, and webcam integration are not yet available.
- Limited to Ubuntu/Debian and Windows platforms (more Linux distributions and potentially MacOS support coming soon).

## Roadmap

We're constantly working to improve ScreenVivid. Here are some features we're planning to add in the future:

- Support for more Linux distributions
- MacOS compatibility
- Advanced editing features (zoom, audio, webcam integration)
- Cloud storage integration

## Support

If you encounter any issues or have questions, please:

1. Check our [FAQ](https://screenvivid.com/faq)
2. Visit our [community forums](https://community.screenvivid.com)
3. Contact us at support@screenvivid.com

## License

ScreenVivid is released under the MIT License. See the LICENSE file for more details.

---

Thank you for choosing ScreenVivid for your screen recording needs! If you find our software helpful, please consider donating to support its development and help us add more amazing features! 💖