#!/bin/bash

# Exit when a command exits with a non-zero code
# Also exit when there are unset variables
set -eu

skip="${1:-}"

main() {
  confirm

  cd $(dirname $0)

  brew_all_the_things
  setup_git
  setup_ssh
  install_gpg
  install_ruby
  install_sshb0t
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
  set +e
  if [ -z "$(fly -v)" ]; then
    wget https://github.com/concourse/concourse/releases/download/v4.2.1/fly_darwin_amd64
    mv fly_darwin_amd64 /usr/local/bin/fly
    chmod +x /usr/local/bin/fly
  fi
  set -e

  echo "Cloning colorschemes..."
  clone_if_not_exist https://github.com/chriskempson/base16-shell.git "${HOME}/.config/colorschemes"

  echo "Configuring Spectacle..."
  cp -f "$(pwd)/com.divisiblebyzero.Spectacle.plist" "${HOME}/Library/Preferences/"

  echo "Setting keyboard repeat rates..."
  defaults write -g InitialKeyRepeat -int 25 # normal minimum is 15 (225 ms)
  defaults write -g KeyRepeat -int 2 # normal minimum is 2 (30 ms)

  GOPATH="${HOME}/go" all_the_repos

  echo "Configuring databases..."
  ./scripts/setup_routing_dbs

  install_tmuxfiles

  echo "Workstation setup complete — open a new window to apply all settings! 🌈"
}

clone_if_not_exist() {
  local remote=$1
  local dst_dir="$2"
  echo "Cloning $remote into $dst_dir"
  if [[ ! -d $dst_dir ]]; then
    git clone "$remote" "$dst_dir"
  fi
}

confirm() {
  if [[ -n "${skip}" ]] && [[ "${skip}" == "-f" ]]; then
    return
  fi

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
  # TODO: Add retry logic around this instead
  set +e

  echo "Installing homebrew..."
  if [[ -z "$(which brew)" ]]; then
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  fi

  echo "Running the Brewfile..."
  brew update
  brew tap Homebrew/bundle
  ln -sf $(pwd)/Brewfile ${HOME}/.Brewfile
  brew bundle --global
  brew bundle cleanup

  set -e
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
  echo "Updating pip..."
  pip3 install --upgrade pip

  echo "Installing python-client for neovim..."
  pip3 install neovim

  echo "Adding yamllint for neomake..."
  pip3 install -q yamllint

  if [[ -f ${HOME}/.config/vim ]]; then
    echo "removing ~/.config/vim dir && ~/.config/nvim"
    rm -rf "${HOME}/.config/vim"
    rm -rf "${HOME}/.config/nvim"
    rm -rf "${HOME}/*.vim"
  else
    clone_if_not_exist https://github.com/luan/nvim "${HOME}/.config/nvim"
  fi

  echo "Adding configuration to nvim..."
  mkdir -p "${HOME}/.config/nvim/user"
  ln -sf "$(pwd)/nvim_config/after.vim" "${HOME}/.config/nvim/user/after.vim"
}

install_sshb0t() {
  latest_tag=$(curl -s https://api.github.com/repos/genuinetools/sshb0t/releases/latest | jq -r .tag_name)

  # If the curl to the github api fails, use latest known version
  if [[ "$latest_tag" == "null" ]]; then
    latest_tag="v0.3.5"
  fi

  # Export the sha256sum for verification.
  sshb0t_sha256=$(curl -sL "https://github.com/genuinetools/sshb0t/releases/download/${latest_tag}/sshb0t-darwin-amd64.sha256" | cut -d' ' -f1)

  # Download and check the sha256sum.
  curl -fSL "https://github.com/genuinetools/sshb0t/releases/download/${latest_tag}/sshb0t-darwin-amd64" -o "/usr/local/bin/sshb0t" \
    && echo "${sshb0t_sha256}  /usr/local/bin/sshb0t" | shasum -a 256 -c - \
    && chmod a+x "/usr/local/bin/sshb0t"

  echo "sshb0t installed!"

  sshb0t --once \
    --user tstannard \
    --user KauzClay \
    --user jeffpak \
    --user angelachin \
    --user utako \
    --user ndhanushkodi \
    --user rosenhouse \
    --user adobley \
    --user bruce-ricard
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
  if [[ ! -d ${HOME}/.ssh ]]; then
    mkdir ${HOME}/.ssh
    chmod 0700 ${HOME}/.ssh
  fi

  if [[ -f ${HOME}/.ssh/config ]]; then
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

  # Deployments Routing:  Pipelines, environment info, helpful scripts
  clone_if_not_exist "git@github.com:cloudfoundry/deployments-routing" "${HOME}/workspace/deployments-routing"

  # Routing Datadog Config: Configure your Data 🐶
  clone_if_not_exist "git@github.com:cloudfoundry/routing-datadog-config" "${HOME}/workspace/routing-datadog-config"

  # Routing Team Checklists: Checklists (on-call, onboarding) and a kind of helpful wiki
  clone_if_not_exist "git@github.com:cloudfoundry/routing-team-checklists" "${HOME}/workspace/routing-team-checklists"

  # Bosh Deployment: We usually use this to bump golang in our releases
  clone_if_not_exist "https://github.com/cloudfoundry/bosh-deployment" "${HOME}/workspace/bosh-deployment"

  # CF Deployment: We use it to deploy Cloud Foundries
  clone_if_not_exist "https://github.com/cloudfoundry/cf-deployment" "${HOME}/workspace/cf-deployment"

  # CF Acceptance Test: 🐱 🐱  or CATS. Happy path integration tests for CF
  clone_if_not_exist "https://github.com/cloudfoundry/cf-acceptance-tests" "${GOPATH}/src/code.cloudfoundry.org/cf-acceptance-tests"

  # CF Smoke Tests: Quick test that pretty much just pushes an app to verify a successful deployment of CF
  clone_if_not_exist "https://github.com/cloudfoundry/cf-smoke-tests" "${GOPATH}/src/code.cloudfoundry.org/cf-smoke-tests"

  # NATS Release: Inherited from Release Integration. We now own this release, which deploys NATS, which is used in CF
  clone_if_not_exist "https://github.com/cloudfoundry/nats-release" "${GOPATH}/src/code.cloudfoundry.org/nats-release"

  # Istio Acceptance Tests: Used to verify Cloud Foundry integration with Istio using real environments and real components
  clone_if_not_exist "https://github.com/cloudfoundry/istio-acceptance-tests" "${GOPATH}/src/code.cloudfoundry.org/istio-acceptance-tests"

  # Istio Release: BOSH release used to deploy Istio, Envoy, Copilot
  clone_if_not_exist "https://github.com/cloudfoundry/istio-release" "${GOPATH}/src/code.cloudfoundry.org/istio-release"

  # Istio Workspace: Use this if you want to work outside of your GOPATH and spin up a Vagrant VM for testing (see istio_docker())
  clone_if_not_exist "https://github.com/cloudfoundry/istio-workspace" "${HOME}/workspace/istio-workspace"

  # Routing API CLI: Used to interact with the Routing API, which can be found in Routing Release
  clone_if_not_exist "https://github.com/cloudfoundry/routing-api-cli" "${GOPATH}/src/code.cloudfoundry.org/routing-api-cli"

  # Routing CI: Scripts and tasks for the Routing Concourse CI
  clone_if_not_exist "https://github.com/cloudfoundry/routing-ci" "${HOME}/workspace/routing-ci"

  # Routing Perf Release: Used to run performance tests against Routing Release
  clone_if_not_exist "https://github.com/cloudfoundry/routing-perf-release" "${GOPATH}/src/code.cloudfoundry.org/routing-perf-release"

  # Routing Release: BOSH Release home to the Gorouter, TCP router, and a bunch of other routing related things. Spelunk! Refactor!
  clone_if_not_exist "https://github.com/cloudfoundry/routing-release" "${GOPATH}/src/code.cloudfoundry.org/routing-release"

  # Routing Sample Apps: Mostly used by developers and PMs for debugging and acceptance. If you don't see what you need, make it and add extensive documentation.
  clone_if_not_exist "https://github.com/cloudfoundry/routing-sample-apps" "${HOME}/workspace/routing-sample-apps"

  # Docs Book CloudFoundry: You'll need this if you want to make any documentation changes for the Cloud Foundry docs site.
  clone_if_not_exist "https://github.com/cloudfoundry/docs-book-cloudfoundry" "${HOME}/workspace/docs-book-cloudfoundry"

  # Docs Running CF: You'll need this if you want to run a docs site locally to make sure your changes are OK.
  clone_if_not_exist "https://github.com/cloudfoundry/docs-running-cf" "${HOME}/workspace/docs-running-cf"

  # Istio Scaling: Used to test the scalability of Istio in a Cloud Foundry deployment
  clone_if_not_exist "https://github.com/cloudfoundry/istio-scaling" "${GOPATH}/src/code.cloudfoundry.org/istio-scaling"

  # Community Bot: an ever changing tool to help with our community responsibilities
  clone_if_not_exist "https://github.com/cf-routing/community-bot" "${GOPATH}/src/github.com/cf-routing/community-bot"

  # Zero Downtime Release: BOSH release for testing app availability
  clone_if_not_exist "https://github.com/cf-routing/zero-downtime-release" "${HOME}/workspace/zero-downtime-release"

  # Pem Librarian: locates and stows pems for Istio/Copilot
  clone_if_not_exist "git@github.com:cloudfoundry/pem-librarian" "${GOPATH}/src/code.cloudfoundry.org/pem-librarian"

  # Pivotal Only ==============================================================================================

  # Routing Support Notes: List of support tickets, past and present, and a handy template to start your own.
  clone_if_not_exist "git@github.com:pivotal/routing-support-notes" "${HOME}/workspace/routing-support-notes"

  # Scripts for generating Istio config for PKS Routing
  clone_if_not_exist "git@github.com:pivotal/k8s-istio-resource-generator" "${GOPATH}/src/github.com/pivotal/k8s-istio-resource-generator"

  # PKS Routing Controller
  clone_if_not_exist "git@github.com:pivotal/pks-routing-controller" "${GOPATH}/src/github.com/pivotal/pks-routing-controller"

  # Pivotal Routing CI -- pipeline and tasks for pivotal ci
  clone_if_not_exist "git@github.com:pivotal/pivotal-routing-ci" "${GOPATH}/src/github.com/pivotal/pivotal-routing-ci"

  # Routing Environments State -- env info for pivotal ci
  clone_if_not_exist "git@github.com:pivotal/routing-environments-state" "${GOPATH}/src/github.com/pivotal/routing-environments-state"
}

main "$@"
