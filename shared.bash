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
    export PATH=$GOPATH/bin:$PATH:/usr/local/go/bin:$HOME/scripts

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
    if [ -d $(brew --prefix)/etc/bash_completion.d ]; then
      for F in $(brew --prefix)/etc/bash_completion.d/*; do
        . ${F}
      done
    fi
  }

  function setup_direnv() {
    eval "$(direnv hook bash)"
  }

  function setup_bosh_env_scripts() {
    local bosh_scripts
    bosh_scripts="${HOME}/workspace/deployments-routing/scripts/script_helpers.sh"
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

gobosh_untarget ()
{
  unset BOSH_BBL_ENVIRONMENT
  unset BOSH_USER
  unset BOSH_PASSWORD
  unset BOSH_ENVIRONMENT
  unset BOSH_GW_HOST
  unset BOSH_GW_PRIVATE_KEY
  unset BOSH_CA_CERT
  unset BOSH_DEPLOYMENT
  unset BOSH_CLIENT
  unset BOSH_CLIENT_SECRET
  unset JUMPBOX_PRIVATE_KEY
}

gobosh_target ()
{
  gobosh_untarget
  if [ $# = 0 ]; then
    return
  fi

  env=$1
  if [ "$env" = "local" ] || [ "$env" = "lite" ]; then
    gobosh_target_lite
    return
  fi

  local BBL_STATE=~/workspace/deployments-routing/$env/bbl-state

  pushd $BBL_STATE 1>/dev/null
    eval "$(bbl print-env)"
  popd 1>/dev/null

  export BOSH_DEPLOYMENT="cf"
  if [ "$env" = "ci" ]; then
    export BOSH_DEPLOYMENT=concourse
  fi

  bosh environment

  # set this variable for humans
  BOSH_BBL_ENVIRONMENT=$env
  export BOSH_BBL_ENVIRONMENT
}

extract_var()
{
  env=$1
  var=$2
  bosh int --path /$var ${HOME}/workspace/deployments-routing/$env/deployment-vars.yml
}

cf_target()
{
  env=$1

  cf api "api.$(get_system_domain $env)" --skip-ssl-validation
  cf auth admin "$(extract_var $env cf_admin_password)"
}

get_system_domain()
{
  local env
  env=$1
  local system_domain
  system_domain=$(extract_var "${env}" system_domain 2>/dev/null)
  if [[ $? -ne 0 ]]; then
    system_domain="${env}".routing.cf-app.com
  fi

  echo "${system_domain}"
}

gobosh_target_lite ()
{
  gobosh_untarget
  local env_dir=${HOME}/workspace/deployments/lite

  pushd $env_dir >/dev/null
    BOSH_CLIENT="admin"
    BOSH_CLIENT_SECRET="$(bosh int ./creds.yml --path /admin_password)"
    BOSH_ENVIRONMENT="vbox"
    BOSH_CA_CERT=/tmp/bosh-lite-ca-cert

    export BOSH_CLIENT
    export BOSH_CLIENT_SECRET
    export BOSH_ENVIRONMENT
    export BOSH_CA_CERT
    bosh int ./creds.yml --path /director_ssl/ca > $BOSH_CA_CERT
  popd 1>/dev/null

  export BOSH_DEPLOYMENT=cf;
}

cf_target_lite()
{
  local env_dir=${HOME}/workspace/deployments/lite

  cf api api.bosh-lite.com --skip-ssl-validation
  adminpw=$(grep cf_admin_password $env_dir/deployment-vars.yml | cut -d ' ' -f2)
  cf auth admin "$adminpw"
}

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
	certstrap --depot-path ${depot_path} init --common-name "${ca_common_name}"
	certstrap --depot-path ${depot_path} request-cert --common-name "${common_name}"
	certstrap --depot-path ${depot_path} sign --CA "${ca_common_name}" "${common_name}"
}

bbl_gcp_creds () {
  lpass show "BBL GCP Creds" --notes
}

eval_bbl_gcp_creds () {
  eval "$(bbl_gcp_creds)"
}
