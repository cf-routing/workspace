#!/bin/bash

# Exit when a command exits with a non-zero code
# Also exit when there are unset variables
set -eu

main() {
  confirm

  cd $(dirname $0)

  brew_all_the_things
  setup_git
  setup_ssh
  install_gpg
  install_ruby
  install_vimfiles

  echo "Symlinking scripts into ~/scripts"
  ln -sfn $PWD/scripts ${HOME}/scripts

  echo "Creating workspace..."
  workspace=${HOME}/workspace
  mkdir -p $workspace

  echo "Creating go/src..."
  go_src=${HOME}/go/src
  if [ ! -e ${go_src} ]; then
    mkdir -pv ${HOME}/go/src
  fi

  if [ -L ${go_src} ]; then
    echo "${go_src} exists, but is a symbolic link"
  fi

  echo "Installing bosh-target..."
  GOPATH="${HOME}/go" go get -u github.com/cf-container-networking/bosh-target

  echo "Installing cf-target..."
  GOPATH="${HOME}/go" go get -u github.com/dbellotti/cf-target

  echo "Installing hclfmt..."
  GOPATH="${HOME}/go" go get -u github.com/fatih/hclfmt

  echo "Installing ginkgo..."
  GOPATH="${HOME}/go" go get -u github.com/onsi/ginkgo/ginkgo

  echo "Installing gomega..."
  GOPATH="${HOME}/go" go get -u github.com/onsi/gomega

  echo "Installing counterfeiter..."
  GOPATH="${HOME}/go" go get -u github.com/maxbrunsfeld/counterfeiter

  echo "Installing fly..."
  if [ -z "$(fly -v)" ]; then
    wget https://github.com/concourse/concourse/releases/download/v3.9.2/fly_darwin_amd64
    mv fly_darwin_amd64 /usr/local/bin/fly
    chmod +x /usr/local/bin/fly
  fi

  echo "Cloning colorschemes..."
  clone_if_not_exist https://github.com/chriskempson/base16-shell.git "${HOME}/.config/colorschemes"

  echo "Configuring Spectacle..."
  cp -f "$(pwd)/com.divisiblebyzero.Spectacle.plist" "${HOME}/Library/Preferences/"

  echo "Setting keyboard repeat rates..."
  defaults write -g InitialKeyRepeat -int 25 # normal minimum is 15 (225 ms)
  defaults write -g KeyRepeat -int 2 # normal minimum is 2 (30 ms)

  all_the_repos

  echo "Configuring databases..."
  ./scripts/setup_routing_dbs

  install_tmuxfiles

  echo "Workstation setup complete — open a new window to apply all settings! 🌈"
}

clone_if_not_exist() {
  local remote=$1
  local dst_dir="$2"
  echo "Cloning $remote into $dst_dir"
  if [ ! -d $dst_dir ]; then
    git clone $remote $dst_dir
  fi
}

confirm() {
  read -r -p "Are you sure? [y/N] " response
  case $response in
    [yY][eE][sS]|[yY])
      return
      ;;

    *)
      echo "Bailing out, you said no"
      exit 187
      ;;
  esac
}

brew_all_the_things() {
  echo "Installing homebrew..."
  if [ -z "$(which brew)" ]; then
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  fi

  echo "Running the Brewfile..."
  brew update
  brew tap Homebrew/bundle
  ln -sf $(pwd)/Brewfile ${HOME}/.Brewfile
  brew bundle --global
  brew bundle cleanup
}

install_gpg() {
  echo "Installing gpg..."
  if ! [[ -d "${HOME}/.gnupg" ]]; then
    mkdir "${HOME}/.gnupg"
    chmod 0700 "${HOME}/.gnupg"

  cat << EOF > "${HOME}/.gnupg/gpg-agent.conf"
default-cache-ttl 3600
pinentry-program /usr/local/bin/pinentry-mac
enable-ssh-support
EOF

    gpg-connect-agent reloadagent /bye > /dev/null
  fi
}

install_vimfiles() {
  if [ -f ${HOME}/.config/vim ]; then
    echo "You already have luan/vimfiles installed. Updating..."
    ${HOME}/.config/vim/update
  else
    clone_if_not_exist https://github.com/luan/vimfiles "${HOME}/.config/vim"
    ${HOME}/.config/vim/install
  fi

  echo "Updating pip..."
  pip3 install --upgrade pip

  echo "Installing python-client for neovim..."
  pip3 install neovim

  echo "Adding yamllint for neomake..."
  pip3 install -q yamllint
}

install_ruby() {
  ruby_version=2.4.2
  echo "Installing ruby $ruby_version..."
  rbenv install -s $ruby_version
  rbenv global $ruby_version
  rm -f ~/.ruby-version
  eval "$(rbenv init -)"
  echo "Symlink the gemrc file to .gemrc..."
  ln -sf $(pwd)/gemrc ${HOME}/.gemrc

  echo "Install the bundler gem..."
  gem install bundler
}

setup_ssh() {
  echo "Setting up SSH config"
  echo "Ignoring ssh security for ephemeral environments..."
  if [ ! -d ${HOME}/.ssh ]; then
    mkdir ${HOME}/.ssh
    chmod 0700 ${HOME}/.ssh
  fi

  if [ -f ${HOME}/.ssh/config ]; then
    echo "Looks like ~/.ssh/config already exists, overwriting..."
  fi

  cp $(pwd)/ssh_config ${HOME}/.ssh/config
  chmod 0644 ${HOME}/.ssh/config
}

install_tmuxfiles() {
  set +e
    tmux list-sessions # this exits 1 if there are no sessions

    if [ $? -eq 0 ]; then
      echo "If you'd like to update your tmux files, please kill all of your tmux sessions and run this script again."
      exit 1
    else
      clone_if_not_exist "https://github.com/luan/tmuxfiles" "${HOME}/workspace/tmuxfiles"
      ${HOME}/workspace/tmuxfiles/install
    fi
  set -e
}

setup_git() {
  echo "Symlink the git-authors file to .git-authors..."
  ln -sf $(pwd)/git-authors ${HOME}/.git-authors

  echo "Copy the shared.bash file into .bash_profile"
  ln -sf $(pwd)/shared.bash ${HOME}/.bash_profile

  echo "Copy the gitconfig file into ~/.gitconfig..."
  cp -rf $(pwd)/gitconfig ${HOME}/.gitconfig

  echo "Copy the inputrc file into ~/.inputrc..."
  ln -sf $(pwd)/inputrc ${HOME}/.inputrc

  echo "Link global .gitignore"
  ln -sf $(pwd)/global-gitignore ${HOME}/.global-gitignore

  echo "link global .git-prompt-colors.sh"
  ln -sf $(pwd)/git-prompt-colors.sh ${HOME}/.git-prompt-colors.sh
}

all_the_repos() {
  echo "Cloning all of the repos we work on..."

  clone_if_not_exist "git@github.com:cloudfoundry/deployments-routing" "${HOME}/workspace/deployments-routing"
  clone_if_not_exist "git@github.com:cloudfoundry/routing-datadog-config" "${HOME}/workspace/routing-datadog-config"
  clone_if_not_exist "git@github.com:cloudfoundry/routing-team-checklists" "${HOME}/workspace/routing-team-checklists"
  clone_if_not_exist "https://github.com/cloudfoundry/bosh-deployment" "${HOME}/workspace/bosh-deployment"
  clone_if_not_exist "https://github.com/cloudfoundry/cf-deployment" "${HOME}/workspace/cf-deployment"
  clone_if_not_exist "https://github.com/cloudfoundry/cf-acceptance-tests" "${HOME}/workspace/cf-acceptance-tests"
  clone_if_not_exist "https://github.com/cloudfoundry/cf-smoke-tests" "${HOME}/workspace/cf-smoke-tests"
  clone_if_not_exist "https://github.com/cloudfoundry/istio-acceptance-tests" "${HOME}/workspace/istio-acceptance-tests"
  clone_if_not_exist "https://github.com/cloudfoundry/istio-release" "${HOME}/workspace/istio-release"
  clone_if_not_exist "https://github.com/cloudfoundry/istio-workspace" "${HOME}/workspace/istio-workspace"
  clone_if_not_exist "https://github.com/cloudfoundry/routing-api-cli" "${HOME}/workspace/routing-api-cli"
  clone_if_not_exist "https://github.com/cloudfoundry/routing-ci" "${HOME}/workspace/routing-ci"
  clone_if_not_exist "https://github.com/cloudfoundry/routing-perf-release" "${HOME}/workspace/routing-perf-release"
  clone_if_not_exist "https://github.com/cloudfoundry/routing-release" "${HOME}/workspace/routing-release"
  clone_if_not_exist "https://github.com/cloudfoundry/routing-sample-apps" "${HOME}/workspace/routing-sample-apps"
}

main "$@"
