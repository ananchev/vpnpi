#!/bin/bash
if [ -n "$1" ]; then
  ansible-playbook --ask-vault-pass -i ansible/vpnpi ansible/deploy.yml --tags "$1" "${@:2}"
else
  ansible-playbook --ask-vault-pass -i ansible/vpnpi ansible/deploy.yml
fi
