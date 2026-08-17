# Where variables come from

Seven sources feed a CloudHost run, and which are live depends on the path taken. Getting this
wrong is the most common reason a variable "isn't being picked up".

## The seven sources, lowest precedence first

1. **Upstream role `defaults/main.yml`** — the floor, and easy to forget because the roles aren't in
   this repo. This is where CentOS 7's MariaDB 10.6 comes from (`nexcess.mariadb`), and where
   `iw_mysql_ver`/`iw_php_ver` default to the string `"system"` (`nexcess.interworx`).

2. **`playbooks/group_vars/`** — `all.yml` (iworx nameservers, theme repo, puppet compile/CA
   servers, `post_run_reboot: true`, the pre-APF firewall rules) and `cloudhost.yml`
   (`cloudhost_import_*`: empty strings for the URLs/names, plus boolean defaults —
   `validate_certs` and `scrub_pii` both default true).

   Note `group_vars/cloudhost.yml` applies to the `cloudhost` group only. Every play in
   `setup.yml` and `base.yml` targets `hosts: cloudhost,saashost`, so a `saashost` host gets
   `all.yml` but not `cloudhost.yml`.

3. **The inventory `.ini`** — and mind the split: its `[all:vars]` group vars rank *below*
   `playbooks/group_vars/` (source 2), while vars set on a host's own inventory line rank *above*
   it. So `post_run_reboot: true` in `group_vars/all.yml` beats `post_run_reboot=false` in
   `[all:vars]`, but loses to the same variable on the host line.

   The `.ini` is nevertheless the only source for a lot that nothing else defines: `nex_zone`
   (which `base.yml` needs to match `region_vars`), `frontnet_addr`/`backnet_addr` (consumed by
   `playbooks/tasks/all.yml` and `nexcess.server`'s firewall rules), the `puppet_*` values,
   `nex_env_target` (gates `nexcess.puppet` and `nexcess.server`'s epel override), and the whole
   `nex_app_*` family — `type`, `version`, `unixuser`, `domain`, `username`, `password`, `email`,
   `base_url`, `secure_base_url`, `admin_location`, `user_firstname`, `user_lastname` — which
   `tasks/import*.yml` and `tasks/install-app*.yml` require and no file in this repo sets.
   `local-testing/README.md`'s `hosts.ini` is a worked example.

4. **`playbooks/os_vars/`** — loaded in `base.yml`'s and `ci_setup.yml`'s `pre_tasks` by filename
   match on `{{ ansible_distribution }}-{{ ansible_distribution_major_version }}.yml`. Per-distro
   *values* belong here. `CentOS-7.yml` selects the iworx 6 archive repo, the custom theme, and a
   php56 base symlink; `Rocky-9.yml` selects the iworx 8 installer, MariaDB 11.4, and PHP 8.1.

   A filename that matches nothing falls through silently to source 1.

5. **Inventory directories** — `{{ inventory_dir }}/project_vars/` (whole directory),
   `region_vars/` (files matching `{{ nex_zone }}.*`), and `host_vars/` (files matching
   `{{ inventory_hostname }}.yml`), loaded by `base.yml`, `import.yml`, and `install-app.yml`.

   All three are loaded with `ignore_errors: true`, so a missing or misnamed directory produces no
   error — just absent variables and a failure later, wherever one was needed.

6. **Hiera YAML from [`nexcess/puppet-config`](https://github.com/nexcess/puppet-config)** —
   `network.yaml`, `interworx.yaml`, `apache.yaml`. Not a separate mechanism: the `playbook` wrapper
   `curl`s them (using `GITHUB_TOKEN`) into `inventories/<project>/<mode>/project_vars/`, so they
   arrive through source 5.

   Only `network.yaml` has a live consumer — the upstream `nexcess.server` role reads
   `nexcess_firewall::cidr_blocks` (office/VPN and login-server SSH allowlists) and
   `r1soft::agent::internal_ips` (backup agent, port 1167), each with a `default()` fallback, so a
   missing key degrades to a closed-off rule rather than an error. `interworx.yaml` and
   `apache.yaml` have no consumer at all: the only two tasks that ever read `interworx::*` keys
   were removed in `7f13a46` as redundant with Puppet, and deleted outright afterwards.
   `./playbook` still fetches all three files.

7. **`-e @file.yml` extra vars** — highest precedence. `local-testing/Dockerfile` passes
   `deployable-vars.yml`, `network.yaml`, `interworx.yaml`, and `apache.yaml` this way, bypassing
   the inventory mechanism entirely.

## The trap: the prebuilt-image path loads neither 5 nor 6

Sources 5 and 6 are loaded in `base.yml`'s `pre_tasks`. `setup.yml` includes `base.yml` only
`when: not nex_skip_roles`, and `nex_skip_roles` is true whenever `/etc/nexcess` exists — i.e. on
any host built from a prebuilt CloudHost image.

So on that path `project_vars/` and `region_vars/` are never loaded, and with them the
puppet-config Hiera YAML. Inventory-adjacent `host_vars/`/`group_vars/` still auto-load, since
Ansible picks those up from the inventory source regardless of any `include_vars`.

That path's work happens in `playbooks/scripts/cloudhost-init.sh.j2`, which templates exactly three
Ansible variables — `iw_master_email`, `iw_master_password`, `iw_license_key`. None of the three is
defined in `group_vars/`, so all three must come from the inventory (`[all:vars]` or `host_vars/`)
or from `-e`. Anything you add to `project_vars/` is invisible to it.

## CI's deliberate inversion

`ci_setup.yml` loads `group_vars/cloudhost.yml`, then `spec/vars.yml`, then `os_vars/` — in that
order, and the order is load-bearing. `spec/vars.yml` pins `iw_php_ver: "7.3"` and
`iw_mysql_ver: "10.6"` for the EL7 baseline; loading `os_vars/` afterwards lets `Rocky-9.yml`'s
8.1/11.4 win on EL9. Reverse the two and CI tests the wrong versions on Rocky — but the two failure
modes differ. PHP is the silent one: `spec/rocky9/cloudhost_iworx_spec.rb` only
asserts the default matches `/opt/remi/php\d+`, so a php73 default would pass. MariaDB isn't
silent — `mariadb_version: "11.4"` comes from `os_vars/Rocky-9.yml` either way, so 11.4 still gets
installed and the db spec still passes; what breaks is the iworx installer being handed `-m 10.6`
against it.

A second side effect: those pins exist only in CI. Neither `os_vars/CentOS-7.yml` nor
`group_vars/` sets `iw_mysql_ver`/`iw_php_ver`, so a real EL7 build runs the InterWorx installer
with `-m system -p system` while CI EL7 runs it with `10.6`/`7.3`.

`spec/vars.yml`'s remaining keys sort into three groups. The credentials are load-bearing —
`iw_master_email`, `iw_master_password`, `iw_license_key` are set nowhere else, and
`nexcess.interworx`'s first task fails without all three (`iw_ns1`-`3` likewise gate four of its
tasks). Of the toggles, only `post_run_reboot: false` changes CI behavior, suppressing the reboot
at the end of `tasks/cloudhost.yml`. `firewall_included: false` and `server_set_sysctl_base: false`
are consumed only by `nexcess.server`, which `ci_setup.yml` never applies, so they're
belt-and-braces; `iw_setup_ssl` and `iw_skip_hosts_edit` have no consumer anywhere in this repo or
in any installed role. CI's real non-destructiveness comes from dropping `base.yml`/`nexcess.server`
and Puppet, not from these keys.

## See also

- [../AGENTS.md](../AGENTS.md) — architecture, file map, commands, conventions
- [../TESTS.md](../TESTS.md) — what the spec suite covers
