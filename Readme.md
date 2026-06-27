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

## Inspiration

[Jaydooooooo/Port-forwarding](https://github.com/Jaydooooooo/Port-forwarding)

## License

MIT
