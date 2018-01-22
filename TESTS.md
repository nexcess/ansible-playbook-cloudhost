# Cloudhost Spec Tests

Currently we run some rudimentary tests on the core playbook to try and catch any immediate issues. This is done on a pr/commit level, as well as on a schedule (to catch issues with upstream providers).

Although the tests are basic, there are a few things that do not currently get tested:

  * [Nexcess Server Role](https://github.com/nexcess/ansible-role-server) - This is due to issues when trying to modify the hosts file inside of a Docker container.
  * [Nexcess Interworx Role](https://github.com/nexcess/ansible-role-interworx) - We don't test the automatic LetsEncrypt setup
  * Any type of post-deployment configuration management

As such, these tests do not cover 100% of a production deployment, but do allow us to catch a fair number of the issues that are seen.

## Testing Locally

To test locally, you just need to have a working Docker installation. From the project root, run `spec/test.sh` with no parameters to build and run the CI tests.

