# Contributing

Ansible playbooks that install and manage Nexcess CloudHost servers with InterWorx.

## Development setup

See [AGENTS.md](AGENTS.md#commands) for build/test/lint commands — not repeated here.

Two things to know before your first change, both covered in
[AGENTS.md](AGENTS.md#conventions): `roles/` is gitignored and reinstalled from `requirements.yml`
on every run (role fixes belong in the upstream `nexcess/ansible-role-*` repos), and
`playbooks/ci_setup.yml` is a trimmed subset of `playbooks/setup.yml` — mirror new roles into it,
but check [ref/ci.md](ref/ci.md) before touching its PHP-version list, which is coupled to a spec
assertion.

## Opening a PR

Use this repo's PR template — link the ticket (Jira/Linear/an issue) and describe how the change
was verified. If the change affects provisioning rather than CI plumbing, say whether you ran it
against a real VM as well as in CI; the spec suite does not cover the `nexcess.server` role, the
LetsEncrypt setup, or post-deployment configuration management ([TESTS.md](TESTS.md)).

## Before you open a PR

- [ ] `spec/test.sh` passes (CentOS 7) and `DISTRO=rocky9 spec/test.sh` passes
- [ ] `ansible-lint` is clean without new `skip_list` entries in `.ansible-lint`
- [ ] Role-order or role-list changes in `playbooks/setup.yml` are mirrored in
      `playbooks/ci_setup.yml`
- [ ] Docs (`README.md`/`AGENTS.md`) updated if this changes how the project is built, run, or used
