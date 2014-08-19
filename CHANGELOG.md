# Chef Init Changelog

## v1.0.0 (Unreleased)
* [FSE-188] Method for stripping secure credentials resulted in intermediate
image with those credentials still present. Stripping out those intermediate
layers is now the responsibility of `chef-init --bootstrap`. Reported by Andrew
Hsu.

## v0.3.1 (2014-08-13)
* Fixed bug when load_current_resource does not pass in run_context to service
resource.

## v0.3.0 (2014-08-11)
* Add `chef-init --verify` command to use to test installation of package.
* Modify internal testing processes including fixtures and types of tests.
* Replace `Chef::Resource::ContainerService` with monkeypatch of
`Chef::Resource::Service` for increased stability.

## v0.2.0 (2014-07-16)
* CLI - Initial Release
  * `--bootstrap` - Launch runit, execute chef-client, then exit.
  * `--onboot` - Launch runit, execute chef-client, then stay alive.
* Custom Resources - Initial Release
  * `container_service` - Takes over for `service` on all platforms. Sends
  `service` resource actions to `runit`.
