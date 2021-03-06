#!/usr/bin/env bash

###
# Following script generates Control Plane Installer artifacts for a release.
#
# INPUTS:
# - KCP_INSTALLER_PUSH_DIR - (optional) directory where kyma-installer docker image is pushed, if specified should ends with a slash (/)
# - KCP_INSTALLER_VERSION - version (image tag) of kyma-installer
# - ARTIFACTS_DIR - path to directory where artifacts will be stored
#
###

set -o errexit

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
RESOURCES_DIR="${CURRENT_DIR}/../resources"
SCRIPTS_DIR="${CURRENT_DIR}/../scripts"
INSTALLER_YAML_PATH="${RESOURCES_DIR}/installer.yaml"
INSTALLER_LOCAL_CONFIG_PATH="${RESOURCES_DIR}/installer-config-local.yaml.tpl"
INSTALLER_CR_PATH="${RESOURCES_DIR}/installer-cr.yaml.tpl"

function generateArtifact() {
    TMP_CR=$(mktemp)

    ${CURRENT_DIR}/create-cr.sh --url "" --output "${TMP_CR}" --version 0.0.1 --crtpl_path "${INSTALLER_CR_PATH}"

    ${CURRENT_DIR}/concat-yamls.sh ${INSTALLER_YAML_PATH} ${TMP_CR} \
      | sed -E ";s;image: eu.gcr.io\/kyma-project\/develop\/installer:.+;image: eu.gcr.io/kyma-project/${KCP_INSTALLER_PUSH_DIR}kcp-installer:${KCP_INSTALLER_VERSION};" \
      > ${ARTIFACTS_DIR}/kcp-installer.yaml

    cp ${INSTALLER_LOCAL_CONFIG_PATH} ${ARTIFACTS_DIR}/kcp-config-local.yaml

    rm -rf ${TMP_CR}
}

function copyKymaInstaller() {
    release=$(<"${RESOURCES_DIR}"/KYMA_VERSION)
    if [[ $release == *PR-* ]] || [[ $release == *master* ]]; then
        curl -L https://storage.googleapis.com/kyma-development-artifacts/${release}/kyma-installer-cluster.yaml -o kyma-installer.yaml
        curl -L https://storage.googleapis.com/kyma-development-artifacts/${release}/is-installed.sh -o ${ARTIFACTS_DIR}/is-kyma-installed.sh
    else
        curl -L https://storage.cloud.google.com/kyma-prow-artifacts/${release}/kyma-installer-cluster.yaml -o kyma-installer.yaml
        cp ${SCRIPTS_DIR}/is-kyma-installed.sh ${ARTIFACTS_DIR}/is-kyma-installed.sh
    fi

    sed -i '/action: install/d' kyma-installer.yaml
    cat ${RESOURCES_DIR}/installer-cr-kyma-dependencies.yaml >> kyma-installer.yaml
    mv kyma-installer.yaml ${ARTIFACTS_DIR}/kyma-installer.yaml
}

function copyCompassInstaller() {
    release=$(<"${RESOURCES_DIR}"/COMPASS_VERSION)
    curl -L https://storage.googleapis.com/kyma-development-artifacts/compass/${release}/compass-installer.yaml -o compass-installer.yaml
    curl -L https://storage.googleapis.com/kyma-development-artifacts/compass/${release}/is-installed.sh -o ${ARTIFACTS_DIR}/is-compass-installed.sh

    sed -i '/action: install/d' compass-installer.yaml
    cat ${RESOURCES_DIR}/installer-cr-compass-dependencies.yaml >> compass-installer.yaml
    mv compass-installer.yaml ${ARTIFACTS_DIR}/compass-installer.yaml
}

generateArtifact
copyKymaInstaller
copyCompassInstaller