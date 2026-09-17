#!/bin/bash
#
# Runs the pi-sandbox apptainer, which serves jupyterlab.
# The container is confined to the submitting user's own scratch - no $HOME,
# no /oak, no group spaces, and no other user's scratch is visible from inside.
# Binds are a runtime thing, so this confinement lives here and not in the sif.
#
# Usage
# 1. Default working directory (/scratch/users/$USER)
# $ bash start.sh pi_sandbox
#
# 2. A subdirectory of the sandbox
# $ bash start.sh pi_sandbox /scratch/users/$USER/myproject

PORT=$1
# id -un rather than $USER or $SCRATCH: this runs under sbatch, where the
# submitting environment is not guaranteed to carry either one.
SANDBOX="/oak/stanford/groups/maggiori/GCAP/sandbox/$(id -un)"
NOTEBOOK_DIR=${2:-$SANDBOX}
CONTAINER="/home/groups/maggiori/apptainers/pi-sandbox.sif"

# apptainer is in the default path on Sherlock - there is no module for it
module load system

# Everything the notebook can reach has to live under the sandbox
case "$NOTEBOOK_DIR" in
    ${SANDBOX}|${SANDBOX}/*) ;;
    *)
        echo "Working directory must be under ${SANDBOX}, got ${NOTEBOOK_DIR}"
        exit 1
        ;;
esac

if [ ! -d "$NOTEBOOK_DIR" ]
then
    echo "Working directory ${NOTEBOOK_DIR} does not exist"
    exit 1
fi

# Sherlock exports default bind paths (/home/users, /oak, /scratch, ...) via
# these variables, which apply even with --containall. Drop them.
unset APPTAINER_BIND APPTAINER_BINDPATH SINGULARITY_BIND SINGULARITY_BINDPATH

echo "Container is ${CONTAINER}"
echo "Notebook directory is ${NOTEBOOK_DIR}"

# Prompt for the jupyterlab terminals: [user@pi-sandbox /absolute/path]$
#
# \w, not $PWD. Something between this file and the terminal expands $VARS
# once - a $PWD here comes out frozen at whatever --pwd was, so the prompt
# never follows a cd. \w is a bash prompt escape, expanded by bash at every
# prompt, so nothing upstream can bake it in. It does render $HOME as ~, but
# $HOME is the throwaway session dir, not anywhere work happens.
#
# The hostname itself cannot be changed here. gethostname() reads the uts
# namespace, and Sherlock's apptainer.conf sets "allow uts ns = no", so
# --hostname is ignored (even with --userns). It is not an image property
# either - /etc/hostname in the sif says "debuerreotype" and hostname(1) still
# reports the compute node. So this is the shell-level equivalent.
#
# Jupyter's terminals take PS1 from the inherited environment - they ignore
# /etc/profile and /etc/bash.bashrc - and what they were picking up is the
# PS1="Apptainer> " that apptainer's own /.singularity.d/env/99-base.sh
# exports. That file only sets it "if [ -z ${PS1:-} ]", and the env stack is
# sourced in lexical order, so a 91- file lands after the image's
# 90-environment.sh and still ahead of 99-base.sh, which then leaves ours
# alone. Note --env cannot do this: apptainer shell-expands --env values, so
# $PWD and the \u \$ escapes are gone before the container sees them. A quoted
# heredoc into the env stack keeps them literal for bash to expand per prompt.
#
# This is exactly what an %environment entry in the def file would do, so if
# the prompt moves into the sif build this bind and its mktemp can go away.
PROMPT_ENV="$(mktemp /tmp/pi-sandbox-prompt.XXXXXX.sh)"
trap 'rm -f "$PROMPT_ENV"' EXIT
cat > "$PROMPT_ENV" <<'PROMPT_ENV_EOF'
export HOSTNAME=pi-sandbox
export PS1='[\u@pi-sandbox \w]\$ '
PROMPT_ENV_EOF

# --containall   empty $HOME and /tmp, minimal /dev, own IPC namespace
# --no-mount     drop the bind paths configured in apptainer.conf
# --bind         the only host paths the container gets
#
# /etc/hosts is one of those apptainer.conf bind paths, so --no-mount takes it
# out along with /home and /oak, and --containall supplies no /etc/resolv.conf
# either. The result is a container with working TCP but no name resolution at
# all: pi lists its models fine (that is just a local JSON file) and then fails
# to connect, because the vLLM baseUrl is a hostname. Sherlock's /etc/hosts
# carries every compute node, so binding it read-only is what makes
# http://<node>:12345/v1 resolve. resolv.conf is only needed for names NOT in
# /etc/hosts - pip, npm, anything off-cluster - so drop that one bind if you
# want the sandbox to stay cluster-local. Neither file contains user data and
# neither widens the filesystem isolation.
# The image's %environment already points the jupyter and XDG dirs at $HOME,
# which --containall makes an empty writable session dir, so leave those alone.
# Empty IdentityProvider.token disables the login prompt (password is empty by
# default). The server only listens on 127.0.0.1 of the compute node, so it is
# reachable through the ssh tunnel - and by anyone else with a shell on that
# node, since the maggiori nodes are shared.
apptainer exec \
    --containall \
    --no-mount hostfs,bind-paths \
    --bind "${SANDBOX}:${SANDBOX}" \
    --bind /etc/hosts:/etc/hosts:ro \
    --bind /etc/resolv.conf:/etc/resolv.conf:ro \
    --bind "${PROMPT_ENV}:/.singularity.d/env/91-pi-sandbox-prompt.sh:ro" \
    --pwd "${NOTEBOOK_DIR}" \
    "${CONTAINER}" \
    jupyter lab --no-browser --ip=127.0.0.1 --port=$PORT \
        --notebook-dir="${NOTEBOOK_DIR}" \
        --IdentityProvider.token=''
