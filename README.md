Nexcess CloudHost Playbooks
===========================

[![Build Status](https://app.travis-ci.com/nexcess/ansible-playbook-cloudhost.svg?branch=master)](https://app.travis-ci.com/github/nexcess/ansible-playbook-cloudhost)

Ansible playbooks that install and manage Nexcess CloudHost servers with InterWorx

Requirements
------------

- A target host running **Rocky Linux 9** (current) or **CentOS 7** (legacy) — those are the two
  distros `playbooks/os_vars/` and the CI matrix cover.
- Ansible on the control host, plus `git` so `ansible-galaxy` can fetch roles over `git+https`.
- If you're running `ansible-core` rather than the full `ansible` package: the
  `community.general` (`ini_file`) and `ansible.posix` (`mount`, `sysctl`, `selinux`) collections,
  without which a setup run fails, plus `community.mysql` if you're running the import playbook.
  `Dockerfile.rocky9` installs all three.
- An `inventories/` directory. It is deliberately **not** in this repo; the cloud deployment
  system supplies it, and `./playbook` expects `inventories/<project>/<mode>/<zone>.ini`.
- `GITHUB_TOKEN` exported, if you want `./playbook` to pull the `nexcess/puppet-config` Hiera
  YAML. Of the three files it fetches, only `network.yaml` currently has a consumer — the
  `nexcess.server` role reads its firewall and backup-agent CIDR lists.
- Docker, for the test suites only.

Usage
-----

Typically this will be used from our cloud deployment system. If you'd like to use it for testing
then do the following:

1. Create a VM to test on.
2. Add an inventory entry for that VM under `inventories/` — the `playbook` script picks the file
   from its `PROJECT`, `MODE`, and `ZONES` variables (currently `metaworx`, `prod`,
   `us-midwest-1`, giving `./inventories/metaworx/prod/us-midwest-1.ini`). Edit those variables if
   you're testing against a different project, mode, or zone.
3. Run `./playbook setup` to start the install process. `MODE` is `prod`, so host key checking
   stays on (`ansible.cfg` sets it too) — add the new VM's host key to `known_hosts` first, or the
   first connection fails.

`./playbook <name>` runs `playbooks/<name>.yml`, so `./playbook ping` gets you a connectivity
check before committing to a full build.

For a fully scripted local run against a Rocky 9 VM — including the SSH key, inventory, and
`deployable-vars.yml` you'll need — follow [local-testing/README.md](local-testing/README.md)
instead. It's the fastest path to a working test deployment.

Testing
-------

```bash
spec/test.sh                 # CentOS 7 (default): build image, lint, run playbook, serverspec
DISTRO=rocky9 spec/test.sh   # Rocky 9
```

Both are what Travis runs. They bind-mount the working tree read-write into the container, so a
run leaves `roles/` and `vendor/` behind (both gitignored). See [TESTS.md](TESTS.md) for what the
suite covers and what it knowingly skips.

Development
-----------

See **[AGENTS.md](AGENTS.md)** for the architecture, the annotated file map, the full command
reference, and the house conventions — including the three that bite first: roles live in other
repos and are wiped and reinstalled on every run, `playbooks/ci_setup.yml` is a subset of
`playbooks/setup.yml` rather than a mirror of it, and four of the `playbooks/tasks/` files are
included twice per play.

[CONTRIBUTING.md](CONTRIBUTING.md) covers the PR process.

Notes
-----

- **A real InterWorx license key is required for any run that installs InterWorx.** The
  `nexcess.interworx` role's first task hard-fails unless `iw_master_email`,
  `iw_master_password`, and `iw_license_key` are all non-empty, and a non-zero activation result
  is fatal as well. CI uses the shared key in `spec/vars.yml`; for a local VM run, take the test
  key from password management as [local-testing/README.md](local-testing/README.md) describes.
