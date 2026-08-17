# How CI differs from production

CI does not run the production playbook. It runs `playbooks/ci_setup.yml`, a trimmed
localhost-targeted variant, inside a systemd Docker container. Knowing exactly where the two
diverge is what keeps a green build from being misleading.

## What `ci_setup.yml` drops

| Production (`setup.yml`) | CI (`ci_setup.yml`) |
|---|---|
| `hosts: cloudhost,saashost` over SSH | `hosts: localhost` |
| Play 1 stats `/etc/nexcess` → `nex_skip_roles`; every role and `tasks/cloudhost.yml` include is gated on it | no equivalent gate — a new `not nex_skip_roles` condition has no CI counterpart |
| Play 4 templates and runs `scripts/cloudhost-init.sh.j2` when `nex_skip_roles` is true | neither branch is ever exercised |
| EL7 play rewrites `CentOS-Base.repo` to `mirror.us-midwest-1.nexcess.net` | `Dockerfile.centos7` repoints at `vault.centos.org` instead, so the Nexcess mirror path is untested |
| `base.yml` → `nexcess.server` role | not run at all |
| `nexcess.php` × 5 (php56/70/71/72/73), gated on `RedHat` **and** major version 7 | same five, gated on major version alone |
| `nexcess.puppet` | not run |
| Puppet registers installed PHP with InterWorx | `iworx-php-scl.yml` included directly |

**The EL7 PHP set is coupled to a spec assertion.** `tasks/iworx-php-scl.yml` picks the default
with `ls -1r --sort version /opt/remi`, i.e. the highest installed version, and
`spec/centos7/cloudhost_iworx_spec.rb` pins `default_php_version: /opt/remi/php73` to match. Change
which PHP versions `ci_setup.yml` installs and that line has to change with it. It's pinned rather
than loosened to `/opt/remi/php\d+` on purpose, so the coupling fails loudly instead of silently
accepting whatever landed. (The two sides were out of step until php72/php73 were added to CI —
`b222a69` had added them to `setup.yml` alone.)

`nexcess.server`'s absence is not an oversight. `TESTS.md` records the reason: the role's
hosts-file edits don't work inside a Docker container. Its `iw_setup_ssl: false` counterpart skips
the automatic LetsEncrypt setup that `TESTS.md` also lists as untested — though note the variable
itself is dead (nothing in this repo or any installed role reads `iw_setup_ssl`, same as
`iw_skip_hosts_edit`).

Because CI never applies `nexcess.server`, `spec/vars.yml`'s `firewall_included: false` and
`server_set_sysctl_base: false` are belt-and-braces: that role is their only consumer.

## What `ci_setup.yml` adds

- `include_vars` of `group_vars/cloudhost.yml` and `../spec/vars.yml`, then `os_vars/` — in that
  order, deliberately. See [variables.md](variables.md).
- `touch /etc/sysconfig/network` (`changed_when: false`) — the iworx installer expects the file to
  exist; the interworx role's own test playbook does the identical touch.
- An EL7-only `iworx-djbdns` yum repo, pulling a djbdns build with a higher `DATALIMIT` so
  `dnscache` doesn't die on "not enough memory for cache of size". The baseurl is a pinned internal
  build path, so EL7 CI breaks if that build is ever removed.
- `nodeworx ... updatePhpMode --php_mode=php-fpm` in `post_tasks`. iworx 8 defaults to `mod_suphp`;
  both distros' iworx specs assert `listPhpInstallMode` matches `php-fpm`.
- `iworx-php-scl.yml`, standing in for the Puppet run production would get.

## What must stay in step

Any role you add to `setup.yml` belongs in `ci_setup.yml` too, and `nexcess.mariadb` must stay ahead
of `nexcess.interworx` in both — the iworx installer talks to MariaDB during its own run, and on
EL9 the reverse order fails with a `mysqld.service` symlink conflict and an unreachable socket.

## Container plumbing

Each workaround in `spec/test.sh` and the Dockerfiles fixes a specific failure; read the comments
before touching them.

- `--cgroupns=host` — CentOS 7's systemd v219 can't navigate Docker 20.10+'s private cgroup
  namespace, so DBus never comes up. The paired `/sys/fs/cgroup` mount must stay `rw` so systemd can
  create its own slice/scope dirs. Both flags are applied to every distro despite the EL7-specific
  rationale.
- `vault.centos.org` rewrites, in `Dockerfile.centos7` for base/updates/extras and again in
  `test.sh` for the SCL repos — CentOS 7 is EOL and `mirrorlist.centos.org` no longer resolves.
- `mkdir -p /etc/sysctl.d` in the Rocky image — iworx 8's `goiworx` license activation throws an
  uncaught exception when the directory is missing.
- Stubbed `/etc/default/grub` and `/sbin/grub2-mkconfig` in the Rocky image — the EL9 quota tasks in
  `tasks/cloudhost.yml` need a `GRUB_CMDLINE_LINUX_DEFAULT` line to match and a `grub2-mkconfig` to
  call.
- `ANSIBLE_INVALID_TASK_ATTRIBUTE_FAILED=false` — demotes the deprecated `static:` attribute in
  `nexcess.php`'s include from fatal to a warning on ansible-core 2.14+. Silently ignored on EL7's
  pinned 2.9.27.

**Gotcha:** `test.sh` builds the image only when the tag is absent, so a local Dockerfile edit is
silently ignored until you `docker rmi nexcess/ansible-playbook-cloudhost:<distro>`. Travis never
hits this — its `before_install` always builds.

## Adding a distro

Five coordinated changes:

1. `playbooks/os_vars/<Distro>-<major>.yml`. Skip it and nothing errors — CI keeps `spec/vars.yml`'s
   `iw_php_ver: 7.3`, `iw_install_script_url` falls back to the role default (the legacy iworx-6
   script), and `mariadb_version` falls back to 10.6. You get a wrong-but-plausible install rather
   than a failure. Set `iw_mysql_ver` if the new distro needs a specific MariaDB from the installer,
   but see [variables.md](variables.md) first — on EL7 it has to stay `"system"` or the installer
   writes a 404 repo.
2. `spec/<distro>/` — the `Rakefile` globs `spec/*` and uses the basename as the task name, and
   `test.sh` invokes `rake spec:${DISTRO}`, so the directory name must equal `DISTRO`.
3. `Dockerfile.<distro>` — `test.sh` derives the filename from `DISTRO`.
4. A `.travis.yml` `env.jobs` matrix entry.
5. A case arm in `spec/test.sh`, which `exit 1`s on an unknown `DISTRO`. Each arm installs Ruby its
   own way (SCL `rh-ruby26` on centos7, AppStream ruby on rocky9).

## See also

- [../AGENTS.md](../AGENTS.md) — architecture, file map, commands, conventions
- [variables.md](variables.md) — the seven variable sources and their precedence
- [../TESTS.md](../TESTS.md) — what the spec suite covers and what it doesn't
