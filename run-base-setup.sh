#!/bin/bash
ansible-playbook --ask-vault-pass -i ansible/vpnpi ansible/base-setup.yml "$@"
