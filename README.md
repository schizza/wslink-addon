# WSLink Add-on for Home Assistant

Small SSL reverse proxy for weather stations that need to send data over HTTPS while Home Assistant itself listens on plain HTTP.

Supports both **PWS protocol** and **WSLink protocol**.

## Introduction

This add-on accepts HTTPS requests from a weather station and forwards them to a local Home Assistant endpoint. It is intended for installations where the station sends data over SSL, while Home Assistant or the target integration expects the traffic only inside the local network over unsecured port.

Although it works well with the SWS12500 integration (as it is created for), it is not limited to SWS12500. It is meant for weather stations and Home Assistant integrations in general whenever station data is forwarded into Home Assistant over HTTPS.

## Features

- Terminates TLS for incoming station traffic
- Forwards both PWS protocol and WSLink protocol (API) requests to Home Assistant
- Generates a self-signed certificate inside the add-on container
- Exposes simple status endpoints for diagnostics and integration use

## Installation

### Add repository in Home Assistant UI

1. Open **Settings > Add-ons** in Home Assistant.
2. Open the **Add-on Store**.

![Add-on store button](README/addonbutton.png)

1. Open the menu in the top-right corner and choose **Repositories**.

![Repositories menu](README/dots.png)

1. Add this repository URL: `https://github.com/schizza/wslink-addon.git`

![Add repository dialog](README/managerepo.png)

1. Refresh the page.
2. Select **WSLink Add-on** and install it.

### Manual installation

1. Clone the repository: `git clone https://github.com/schizza/wslink-addon.git`
2. Copy the directory to `/usr/share/hassio/addons/local/`

## Configuration

![Configuration](README/configuration.png)

Before starting the add-on, configure these fields:

- `Host name`: DNS name included in the generated certificate. Use the hostname that your station connects to. You can leave `homeassistant.local`.
- `HA IP address`: IP address included in the generated certificate. This field is required.
- `HA port`: Plain HTTP port where Home Assistant listens internally, usually `8123`.
- `cert valid for`: Number of days the generated self-signed certificate stays valid.
- `auto recreate certificate`: Recreates the certificate when it no longer matches the configured host name or IP address, or when it is near expiration. Restart the add-on after changing these settings.

## Usage

1. Start the add-on from the Home Assistant add-on page.
2. Check the add-on logs and confirm that the certificate was created and nginx started successfully.
3. Configure the weather station to send data to the add-on over HTTPS.
4. Configure the target Home Assistant integration according to the protocol used by the station.

Some stations are configured through the WSLink application but still send data using the older PWS protocol over SSL. If data does not appear in Home Assistant, check whether the target integration expects WSLink or PWS and adjust the integration settings accordingly.

## Status endpoints

The add-on exposes two status endpoints:

- `/status`: Public status endpoint intended for users and diagnostics. It reports whether the add-on is running and which external port is currently used to reach it.
- `/status/internal`: Internal status endpoint intended for integrations. It contains upstream details for Home Assistant integrations that consume weather-station traffic forwarded by this add-on, and it is not meant as the primary user-facing endpoint.

Example URLs:

- `https://<home-assistant-host>:<configured-addon-port>/status`
- `https://<home-assistant-host>:<configured-addon-port>/status/internal`

Use `/status` when you want to quickly verify that the add-on is reachable from the outside. The integration should use `/status/internal`.

## Uninstallation

1. Stop the add-on.
2. Uninstall it from Home Assistant.
3. Remove local files if you installed it manually.
4. Reconfigure the affected Home Assistant integration so it no longer expects WSLink/PWS traffic through this add-on.

## Contributing

Contributions are welcome. Create an issue before starting larger changes so the approach can be discussed first.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
