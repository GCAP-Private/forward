#!/bin/bash
#
# Runs the pi-sandbox apptainer, which serves jupyterlab.
# The container is confined to the submitting user's own sandbox directory in the
# maggiori oak space - no $HOME, no $SCRATCH, no rest of /oak, and no other
# user's sandbox is visible from inside.
# Binds are a runtime thing, so this confinement lives here and not in the sif.
#
# The sandbox directory is created on first run, so a new user does not have to
# set anything up by hand.
#
# Usage
# 1. Default working directory
#    (/oak/stanford/groups/maggiori/GCAP/sandbox/$USER)
# $ bash start.sh pi_sandbox
#
# 2. A subdirectory of the sandbox
# $ bash start.sh pi_sandbox /oak/stanford/groups/maggiori/GCAP/sandbox/$USER/myproject

PORT=$1
# id -un rather than $USER: this runs under sbatch, where the submitting
# environment is not guaranteed to carry it.
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

# A first-time user has no sandbox of their own yet, so create it here rather
# than making them go do it on a login node first. It has to exist before the
# --bind below either way: apptainer will not create a missing bind source.
#
# 700 explicitly, and not left to the umask: the parent is a shared group
# directory, so the default would be group-readable and every other maggiori
# member could read this user's work from a login node. Only applied when we
# create the directory, so a user who has deliberately loosened their own
# sandbox keeps that.
if [ ! -d "$SANDBOX" ]
then
    echo "Creating sandbox ${SANDBOX}"
    if ! mkdir -p "$SANDBOX" || ! chmod 700 "$SANDBOX"
    then
        echo "Could not create sandbox ${SANDBOX}"
        exit 1
    fi
fi

# $2 can name a subdirectory that does not exist yet
if [ ! -d "$NOTEBOOK_DIR" ]
then
    echo "Creating working directory ${NOTEBOOK_DIR}"
    if ! mkdir -p "$NOTEBOOK_DIR"
    then
        echo "Could not create working directory ${NOTEBOOK_DIR}"
        exit 1
    fi
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

# ---------------------------------------------------------------------------
# SLURM client bridge (PI_SANDBOX_SLURM=0 to switch off)
#
# Lets the agent submit the ai1 DAG batch job - see the ai1-dag skill baked
# into the image. Understand what it opens before leaving it on: a job
# submitted from inside runs OUTSIDE the container, as you, with $HOME, all of
# $OAK and $SCRATCH visible. The filesystem confinement below does not reach
# submitted jobs. Everything else in the sandbox works with this off; the
# wrappers just print how to turn it back on.
#
# The host's Slurm is bound in rather than baked into the SIF so a cluster-side
# upgrade cannot strand a stale client in the image. Four pieces:
#
#   binaries  -> /opt/slurm-host/bin  (wrapped by /opt/slurm-bin/*, which scope
#                LD_LIBRARY_PATH to the exec so el7 libz/libselinux cannot
#                shadow Debian's for the rest of the container)
#   libraries -> /opt/slurm-libs      CentOS 7 .so files bookworm does not have
#   plugins   -> /usr/lib64/slurm     path is compiled into the binaries
#   auth      -> /run/slurm           sack.socket + the configless conf cache
#
# Sherlock runs AuthType=auth/slurm, not munge - there is no munge socket on
# the node at all. Auth is the peer credentials on sack.socket
# (AuthInfo=use_client_ids), so no key material crosses into the container.
# /var/spool/slurmd/conf-cache is bound because /run/slurm/conf is a symlink
# to it; without the target the clients find no configuration.
#
# The library list is explicit rather than "bind /usr/lib64": that directory
# also holds the el7 glibc, and putting it on LD_LIBRARY_PATH next to the
# container's own ld.so is how you get a process that cannot start at all.
SLURM_BINDS=()
if [ "${PI_SANDBOX_SLURM:-1}" != "0" ]; then
    slurm_ok=1
    for f in /run/slurm/sack.socket /var/spool/slurmd/conf-cache/slurm.conf; do
        [ -e "$f" ] || { echo "WARNING: $f missing - no SLURM in the sandbox"; slurm_ok=0; }
    done
    if [ "$slurm_ok" = 1 ]; then
        for b in sbatch squeue scancel sacct sinfo scontrol; do
            [ -x "/usr/bin/$b" ] &&
                SLURM_BINDS+=(--bind "/usr/bin/$b:/opt/slurm-host/bin/$b:ro")
        done
        # Closure of what the client binaries and their auth/serializer
        # plugins dlopen, minus what glibc provides. Regenerate after a Slurm
        # upgrade with:
        #   ldd /usr/bin/sbatch /usr/lib64/slurm/{auth_slurm,serializer_*}.so
        for l in libcom_err.so.2 libcrypto.so.10 libgssapi_krb5.so.2 \
                 libjansson.so.4 libjwt.so.1 libk5crypto.so.3 libkeyutils.so.1 \
                 libkrb5.so.3 libkrb5support.so.0 libpcre.so.1 libselinux.so.1 \
                 libssl.so.10 libz.so.1 libjson-c.so.2 libyaml-0.so.2 \
                 libreadline.so.6 libhistory.so.6 libtinfo.so.5; do
            src="$(readlink -f "/usr/lib64/$l" 2>/dev/null)"
            [ -n "$src" ] && [ -e "$src" ] &&
                SLURM_BINDS+=(--bind "${src}:/opt/slurm-libs/${l}:ro")
        done
        SLURM_BINDS+=(
            --bind /usr/lib64/slurm:/usr/lib64/slurm:ro
            --bind /run/slurm:/run/slurm
            --bind /var/spool/slurmd/conf-cache:/var/spool/slurmd/conf-cache:ro
        )
        # The ai1 checkout, so the agent can `sbatch /opt/ai1/sherlock/
        # ai1.sbatch`. A container-only path is fine for the script itself:
        # sbatch transmits the script's CONTENTS to the controller. The YAML
        # passed as its argument is different - that one is resolved on the
        # host when the job starts, so it has to live under the sandbox leaf,
        # the one tree with the same absolute path on both sides.
        #
        # Default expanded here, next to its only use. A top-of-file
        # assignment is the line a hand-merge of this block drops, and then
        # ${AI1_DIR} expands to nothing, `-d ""` is false, and the only
        # symptom is `sbatch: error: Unable to open file
        # /opt/ai1/sherlock/ai1.sbatch` much later, inside the container.
        # Not derived from $0: under sbatch the controller runs a copy of
        # this script out of the SLURM spool, so dirname $0 is the spool.
        ai1_dir="${AI1_DIR:-$HOME/ai1}"
        if [ -d "$ai1_dir" ]; then
            SLURM_BINDS+=(--bind "${ai1_dir}:/opt/ai1:ro")
        else
            echo "WARNING: ai1 checkout '${ai1_dir}' not found - /opt/ai1 will be" \
                 "empty and the agent cannot sbatch sherlock/ai1.sbatch." \
                 "Set AI1_DIR to your checkout."
        fi
    fi
fi

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
    ${SLURM_BINDS[@]+"${SLURM_BINDS[@]}"} \
    --pwd "${NOTEBOOK_DIR}" \
    "${CONTAINER}" \
    jupyter lab --no-browser --ip=127.0.0.1 --port=$PORT \
        --notebook-dir="${NOTEBOOK_DIR}" \
        --IdentityProvider.token=''
