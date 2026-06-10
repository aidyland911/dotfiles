# dotfiles
Handy tools

## Ansible setup

The shell installers have been converted to Ansible — one playbook per OS.
See [ansible/README.md](ansible/README.md) for the full conversion notes.

```bash
cd ~/dotfiles/ansible

# First time only:
sudo apt install -y python3-venv python3-pip   # Ubuntu (RHEL: sudo dnf install -y python3-pip)
python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt

ansible-playbook -i inventory.ini rhel.yml -K     # on RHEL
ansible-playbook -i inventory.ini ubuntu.yml -K   # on Ubuntu
```
