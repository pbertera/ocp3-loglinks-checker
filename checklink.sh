#!/usr/bin/env bash

#
# Derived from https://github.com/kubernetes/kubernetes/issues/52172#issuecomment-346075080
#
DRY_RUN=${DRY_RUN:-yes}
VERBOSE=${VERBOSE:-no}

set -e

say(){
  if [ "${VERBOSE}" == "yes" -o "$2" == "1" ]; then
    echo $1
  fi
}

if [ ! -d /var/lib/docker/containers ]; then
  echo "/var/lib/docker/containers doesn't exist; aborting" 1>&2
  exit 1
fi

cd /var/lib/docker/containers
while true ; do
  for DOCKER_ID in *; do
    CONTAINER="$(cat ${DOCKER_ID}/config.v2.json | jq '{Labels:.Config.Labels, LogPath, ID}')"
    CONTAINER_ID="$(echo ${CONTAINER} | jq -r .ID)"
    CONTAINER_NAME="$(echo ${CONTAINER} | jq -r '.Labels["io.kubernetes.container.name"]')"
    LOG_PATH="$(echo ${CONTAINER} | jq -r .LogPath)"
    POD_NAME="$(echo ${CONTAINER} | jq -r '.Labels["io.kubernetes.pod.name"]')"
    POD_NAMESPACE="$(echo ${CONTAINER} | jq -r '.Labels["io.kubernetes.pod.namespace"]')"
    LINK1_NAME="$(printf "%s_%s_%s-%s" "$POD_NAME" "$POD_NAMESPACE" "$CONTAINER_NAME" "$CONTAINER_ID" | cut -c 1-251)"
    LINK1_FILENAME=$(printf "/var/log/containers/%s.log" "$LINK1_NAME")
    LINK2_FILENAME=$(echo ${CONTAINER} | jq -r '.Labels["io.kubernetes.container.logpath"]')

    if [ "${CONTAINER_NAME}" == "POD" -o "${CONTAINER_NAME}" == "null" ]; then
       continue # skip standalone containers and pod namspace howner container
    fi
    
    if [ "${DRY_RUN}" != "no" ]; then
      say "Mode: dry-run"
    fi
    
    say "Pod: ${POD_NAME} (${CONTAINER_ID}}"
    say "Container: ${CONTAINER_NAME}"
    say "Namespace: ${POD_NAMESPACE}"
    
    if [ -n "${LINK1_FILENAME}" -a ! -e "${LINK1_FILENAME}" -a -e "${LOG_PATH}" ] ; then
      say "Link1 KO: ${LINK1_FILENAME} -> ${LOG_PATH}" 1 
      if [ "${DRY_RUN}" == "no" ]; then
        ln -s ${LOG_PATH} ${LINK1_FILENAME}
      fi
    else
      say "Link1 OK: ${LINK1_FILENAME} -> ${LOG_PATH}"
    fi

    if [ "${LINK2_FILENAME}" = "null" ] ; then
        LINK2_FILENAME=""
    fi
    if [ -n "${LINK2_FILENAME}" -a ! -e "${LINK2_FILENAME}" -a -e "${LINK1_FILENAME}" ] ; then
      say "Link2 KO: ${LINK1_FILENAME} -> ${LINK2_FILENAME}" 1
      if [ "${DRY_RUN}" == "no" ]; then
        if [ ! -d "$(dirname ${LINK2_FILENAME})" ] ; then
          mkdir -p "$(dirname ${LINK2_FILENAME})"
        fi
        ln -s ${LINK1_FILENAME} ${LINK2_FILENAME}
      fi
    else
      say "Link2 OK: ${LINK1_FILENAME} -> ${LINK2_FILENAME}"
    fi
    say ""
  done
 sleep 60
done

