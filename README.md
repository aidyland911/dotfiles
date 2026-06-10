# dotfiles
Handy tools

## Ansible setup

The shell installers have been converted to Ansible — one playbook per OS.
See [ansible/README.md](ansible/README.md) for the full conversion notes.

```bash
cd ~/dotfiles/ansible
python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt  # first time only
ansible-playbook -i inventory.ini rhel.yml -K     # on RHEL
ansible-playbook -i inventory.ini ubuntu.yml -K   # on Ubuntu
```
