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

    # NOTE: you'll have to run `git init` once again in pre-existing repos to
    # ensure the hook file gets copied locally. afterward, use the normal
    # git commands (e.g. `git commit` instead of `git ci`) and the commit msg
    # hook will append a `Co-authored-by` trailer for each co-author.
    export GIT_DUET_CO_AUTHORED_BY=1

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


gimme_certs() {
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

eval_bbl_gcp_creds() {
  eval "$(bbl_gcp_creds)"
}

pullify() {
  git config --add remote.origin.fetch '+refs/pull/*/head:refs/remotes/origin/pr/*'
  git fetch origin
}

istio_docker() {
  local istio_dir
  istio_dir="${1}"

  if lpass status; then
    if [[ -z "${istio_dir}" ]]; then
      echo "WARNING: istio_dir not set"
      echo "Setting istio directory to ~/workspace/istio-release/src/istio.io/istio"
      echo "You may optionally pass your preferred istio directory as the first argument 😀 "
      istio_dir="${HOME}/workspace/istio-release/src/istio.io/istio"
    else
      echo "istio_directory set to ${istio_dir}"
    fi

    echo "Getting docker auth token..."
    local token
    token=$(curl -s -H "Content-Type: application/json" -X POST -d '{"username": "'$(lpass show "Shared-CF Routing"/hub.docker.com --username)'", "password": "'$(lpass show "Shared-CF Routing"/hub.docker.com --password)'"}' https://hub.docker.com/v2/users/login/ | jq -r .token)

    echo "Getting istio/ci tags..."
    local tag
    tag=$(curl -s -H "Authorization: JWT ${token}" https://hub.docker.com/v2/repositories/istio/ci/tags/?page_size=100 | jq -r '.results|.[0].name')

    echo "Getting most recent istio/ci images..."
    docker pull istio/ci:"${tag}"

    local image_id
    image_id=$(docker images -f reference=istio/ci --format "{{.ID}}" | head -n1)

    docker run -u root -it --cap-add=NET_ADMIN -v "${istio_dir}":/go/src/istio.io/istio "${image_id}" /bin/bash
  else
    echo "Please log in to lastpass using the lastpass cli. 😀"
  fi
}

default_hours() {
  local current_hour=$(date +%H | sed 's/^0//')
  local result=$((17 - current_hour))
  if [[ ${result} -lt 1 ]]; then
    result=1
  fi
  echo -n ${result}
}

set_key() {
  local hours=$1

  /usr/bin/ssh-add -D

  echo "Setting hours to: $hours"
  lpass show --notes 'ProductivityTools/id_rsa' | /usr/bin/ssh-add -t ${hours}H -
}

set-git-keys() {
  local email=$1
  local hours=$2

  if [[ -z ${email} ]]; then
    echo "Usage: $0 [LastPass email or git author initials] [HOURS (optional)]"
    return
  fi

  if git_author_path "/authors/$email" >/dev/null 2>&1; then
    echo "Adding key for $(bosh int ${HOME}/.git-authors --path="/authors/$email" | sed 's/;.*//')"
    email="$(bosh int ${HOME}/.git-authors --path="/authors/$email" | sed 's/;.*//')@$(bosh int ${HOME}/.git-authors --path="/email/domain")"
  fi

  if [[ -z ${hours} ]]; then
    hours=$(default_hours)
  fi

  if ! [[ $(lpass status) =~ $email ]]; then
    lpass login "$email"
  fi
  set_key ${hours}
}
export PATH="/usr/local/opt/apr/bin:$PATH"
export PATH="/usr/local/opt/apr-util/bin:$PATH"
