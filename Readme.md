# realm-onekey

A script to manage Realm Port Forwarding service.

## Usage

```sh
wget https://raw.githubusercontent.com/backrunner/realm-onekey/main/realm-onekey.sh && chmod +x realm-onekey.sh && ./realm-onekey.sh
```

## Install management script

```sh
wget https://raw.githubusercontent.com/backrunner/realm-onekey/main/realm-onekey.sh
chmod +x realm-onekey.sh
sudo ./realm-onekey.sh install
realm-manager
```

## Uninstall management script

```sh
sudo realm-manager uninstall
```

To remove the Realm service and data at the same time:

```sh
sudo realm-manager uninstall --purge
```

## Auto revive health check

When `realm` is started from the script, it also installs and enables a `realm-healthcheck.timer` systemd task. The timer checks `realm.service` periodically and restarts it if the service is down or the configured listen ports are no longer held by the Realm process.

```sh
sudo realm-manager service upgrade
sudo realm-manager healthcheck status
sudo realm-manager healthcheck enable
sudo realm-manager healthcheck disable
```

## Inspiration

[Jaydooooooo/Port-forwarding](https://github.com/Jaydooooooo/Port-forwarding)

## License

MIT
