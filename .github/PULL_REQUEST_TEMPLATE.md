**Ticket:** <!-- Hyperlink the issue, e.g. [ENG-2104](https://liquidweb.atlassian.net/browse/ENG-2104)
(Jira) or [TEAM-123](https://linear.app/nexcess/issue/TEAM-123/slug) (Linear) — required, or state
why there isn't one -->

## Why

<!-- What problem does this solve, or what requirement does it fulfill? One sentence is usually
enough if there's a ticket — it should contain the details. -->

## What

<!-- What changed? Bullet points of the approach taken. -->

### Blast radius

<!-- Which distros does this touch (CentOS 7 / Rocky 9 / both)? Which playbook paths — the
fresh-VM role run, the prebuilt-image `cloudhost-init.sh` path, import, install-app, or CI only?
Does it change a role version or a `requirements.yml` source? -->

### Deviations from spec

<!-- Bullet points: what, if anything, changed between the ticket's description and the final
implementation, and why. Delete this section if there's no spec to deviate from. -->

## Reading guide

<!-- Optional for a small change. For anything touching more than one file, map it for reviewers
before they read the diff. -->

| File | What to look at | Why |
|---|---|---|
| `` | … | … |

## Test plan

**Automated tests added/updated:**
- [ ] …

**Manual verification steps:**
1. …

<!-- If this changes provisioning behaviour, say whether you ran it against a real VM
(local-testing/README.md) as well as CI — the spec suite does not cover nexcess.server, the
LetsEncrypt setup, or any post-deployment config management (see TESTS.md). -->

## Deploy notes

<!-- Delete this section if not needed. -->

**Key/secret changes:** <!-- new secrets to provision, keys to issue, or config to update? -->
**Rollout order:** <!-- any sequencing required (e.g. a puppet-config change that must land first)? -->
**Rollback:** <!-- how to revert if this causes a problem in production? -->

## Checklist

- [ ] `spec/test.sh` passes (CentOS 7)
- [ ] `DISTRO=rocky9 spec/test.sh` passes
- [ ] `ansible-lint` is clean without adding anything to `.ansible-lint`'s `skip_list`
- [ ] A newly added role, or a role-order change, in `playbooks/setup.yml` is mirrored in
      `playbooks/ci_setup.yml` (its 3-vs-5 EL7 PHP split is coupled to a spec assertion — see
      `ref/ci.md` before changing that)
- [ ] New tasks in one of the four double-included files (`all.yml`, `cloudhost.yml`,
      `import.yml`, `install-app.yml`) guard on `when: mode == "pre"` / `"post"` as appropriate
- [ ] Docs updated (`README.md`/`AGENTS.md`) if this changes how the project is built, run, or used
- [ ] No secrets, tokens, or real customer/financial data included
