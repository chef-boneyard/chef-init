# Chef Init Changelog

## v1.0.0.rc.0

## v0.2.0 (2014-07-16)
* CLI - Initial Release
  * `--bootstrap` - Launch runit, execute chef-client, then exit.
  * `--onboot` - Launch runit, execute chef-client, then stay alive.
* Custom Resources - Initial Release
  * `container_service` - Takes over for `service` on all platforms. Sends
  `service` resource actions to `runit`.
