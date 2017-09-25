Nexcess CloudHost Playbooks
===========================

Ansible playbooks that install and manage Nexcess CloudHost servers with InterWorx

Requirements
------------

el7

Usage
-----

Typically this will be used from our cloud deployment system.  If you'd like to use it for testing then do the following:

1. Create a VM to test on.
2. Edit ./inventories/metaworx/dev/us-midwest-1.ini and add your inventory entry for the VM created in (1).
3. Run ./playbook setup to start the install process.

Notes
-----

- An InterWorx license is needed if you want to do tests on InterWorx itself.  If you're just testing the setup procedure then no InterWorx license is required.
