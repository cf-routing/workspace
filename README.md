# workspace configuration

# why?
there are a whole host of tools to setup workstations but none are simple,
this is an attempt at simple.

# installation
On a freshly imaged machine, open **Terminal**
```
sudo xcodebuild -license  # follow the interactive prompts
mkdir -p ~/workspace
cd ~/workspace
git clone https://github.com/cf-routing/workspace routing-workspace
cd routing-workspace
./install.sh
```

To load iTerm preferences, point to this directory under `iTerm2` >
`Preferences` > `Load preferences from a custom folder or URL`.

# assumptions
- install everything with brew
- spectacle for window management
- neovim is the only vim
- the less in the vim config, the better
- we remote pair with [ngrok+tmux](./REMOTE_PAIRING.md) or Slack
