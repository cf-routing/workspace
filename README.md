# workspace configuration
simple bash scripts for workstation setup

## installation
On a freshly imaged machine:

- Ensure your GitHub SSH key is authorized for use in the `pivotal` org
  - Ensure the "SSO" button [on this page](https://github.com/settings/keys) is
    green

- open **Terminal**, load your SSH key and run
  ```
  sudo xcodebuild -license  # follow the interactive prompts
  mkdir -p ~/workspace
  cd ~/workspace
  git clone https://github.com/cf-routing/workspace routing-workspace
  cd routing-workspace
  ./install.sh
  ```

- If you encounter problems with the script, fix them and re-run!

- Launch Spectacle and follow instructions to configure it at boot

To load iTerm preferences, point to this directory under `iTerm2` >
`Preferences` > `Load preferences from a custom folder or URL`.

## patterns
- keep it simple
- declarative and idempotent
- install as much as possible via brew
- spectacle for window management
- [luan vim](https://github.com/luan/vimfiles) with neovim
- remote pair with [ngrok+tmux](./REMOTE_PAIRING.md)
