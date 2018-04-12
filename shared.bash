#!/usr/bin/env bash

function main() {
  function setup_aliases() {
    alias vim=nvim
    alias vi=nvim
    alias ll="ls -al"
    alias be="bundle exec"
    alias bake="bundle exec rake"
    alias drm='docker rm $(docker ps -a -q)'
    alias drmi='docker rmi $(docker images -q)'
    alias bosh2=bosh

    #git aliases
    alias gst="git status"
    alias gd="git diff"
    alias gap="git add -p"
    alias gup="git pull -r"
    alias gp="git push"
    alias ga="git add"
  }

  function setup_environment() {
    export CLICOLOR=1
    export LSCOLORS exfxcxdxbxegedabagacad

    # go environment
    export GOPATH=$HOME/go

    # git duet config
    export GIT_DUET_GLOBAL=true
    export GIT_DUET_ROTATE_AUTHOR=1

    # setup path
    export PATH=$GOPATH/bin:$PATH:/usr/local/go/bin:$HOME/scripts:$HOME/workspace/routing-ci/scripts

    export EDITOR=nvim
  }

  function setup_rbenv() {
    eval "$(rbenv init -)"
  }

  function setup_aws() {
    # set awscli auto-completion
    complete -C aws_completer aws
  }

  function setup_fasd() {
    local fasd_cache
    fasd_cache="$HOME/.fasd-init-bash"

    if [ "$(command -v fasd)" -nt "$fasd_cache" -o ! -s "$fasd_cache" ]; then
      fasd --init posix-alias bash-hook bash-ccomp bash-ccomp-install >| "$fasd_cache"
    fi

    source "$fasd_cache"
    eval "$(fasd --init auto)"
  }

  function setup_completions() {
    [ -f /usr/local/etc/bash_completion ] && . /usr/local/etc/bash_completion
  }

  function setup_direnv() {
    eval "$(direnv hook bash)"
  }

  function setup_bosh_env_scripts() {
    local bosh_scripts
    bosh_scripts="${HOME}/workspace/routing-ci/scripts/script_helpers.sh"
    [[ -s "${bosh_scripts}" ]] && source "${bosh_scripts}"
  }

  function setup_gitprompt() {
    if [ -f "$(brew --prefix)/opt/bash-git-prompt/share/gitprompt.sh" ]; then
      # git prompt config
      export GIT_PROMPT_SHOW_UNTRACKED_FILES=normal
      export GIT_PROMPT_ONLY_IN_REPO=0
      export GIT_PROMPT_THEME="Custom"

      __GIT_PROMPT_DIR=$(brew --prefix)/opt/bash-git-prompt/share
      source "$(brew --prefix)/opt/bash-git-prompt/share/gitprompt.sh"
    fi
  }

  function setup_colors() {
    local colorscheme
    colorscheme="${HOME}/.config/colorschemes/scripts/base16-monokai.sh"
    [[ -s "${colorscheme}" ]] && source "${colorscheme}"
  }

  function setup_gpg_config() {
    local status
    status=$(gpg --card-status &> /dev/null; echo $?)

    if [[ "$status" == "0" ]]; then
      export SSH_AUTH_SOCK="${HOME}/.gnupg/S.gpg-agent.ssh"
    fi
  }

  local dependencies
    dependencies=(
        aliases
        environment
        colors
        rbenv
        aws
        fasd
        completions
        direnv
        gitprompt
        gpg_config
        bosh_env_scripts
      )

  for dependency in ${dependencies[@]}; do
    eval "setup_${dependency}"
    unset -f "setup_${dependency}"
  done
}

function reload() {
  source "${HOME}/.bash_profile"
}

function reinstall() {
  local workspace
  workspace="${HOME}/workspace/routing-workspace"

  if [[ ! -d "${workspace}" ]]; then
    git clone https://github.com/rosenhouse/workspace "${workspace}"
  fi

  pushd "${workspace}" > /dev/null
    git diff --exit-code > /dev/null
    if [[ "$?" = "0" ]]; then
      git pull -r
      bash -c "./install.sh"
    else
      echo "Cannot reinstall. There are unstaged changes in $workspace"
      git diff
    fi
  popd > /dev/null
}

main
unset -f main


cf_seed()
{
  cf create-org o
  cf create-space -o o s
  cf target -o o -s s
}


gimme_certs () {
	local common_name
	common_name="${1:-fake}"
	local ca_common_name
	ca_common_name="${2:-${common_name}_ca}"
	local depot_path
	depot_path="${3:-fake_cert_stuff}"
	certstrap --depot-path ${depot_path} init --passphrase '' --common-name "${ca_common_name}"
	certstrap --depot-path ${depot_path} request-cert --passphrase '' --common-name "${common_name}"
	certstrap --depot-path ${depot_path} sign --passphrase '' --CA "${ca_common_name}" "${common_name}"
}

bbl_gcp_creds () {
  lpass show "BBL GCP Creds" --notes
}

eval_bbl_gcp_creds () {
  eval "$(bbl_gcp_creds)"
}

pullify () {
  git config --add remote.origin.fetch '+refs/pull/*/head:refs/remotes/origin/pr/*'
  git fetch origin
}
