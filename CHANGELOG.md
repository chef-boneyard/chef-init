# Chef Init Changelog

## v1.0.0.rc.0
* Add `chef-init --verify` command to use to test installation of package.
* Modify internal testing processes including fixtures and types of tests.

## v0.2.0 (2014-07-16)
* CLI - Initial Release
  * `--bootstrap` - Launch runit, execute chef-client, then exit.
  * `--onboot` - Launch runit, execute chef-client, then stay alive.
* Custom Resources - Initial Release
  * `container_service` - Takes over for `service` on all platforms. Sends
  `service` resource actions to `runit`.
