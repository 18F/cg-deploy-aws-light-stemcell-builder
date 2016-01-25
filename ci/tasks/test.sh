#!/usr/bin/env bash

set -e

source builder-src/ci/tasks/utils.sh

check_param access_key
check_param secret_key
check_param bucket_name
check_param region
check_param ami_fixture_id

export AWS_ACCESS_KEY_ID=$access_key
export AWS_SECRET_ACCESS_KEY=$secret_key

export AWS_BUCKET_NAME=$bucket_name
export AWS_REGION=$region
export AMI_FIXTURE_ID=$ami_fixture_id
export OUTPUT_STEMCELL_PATH=$PWD

echo "Checking Java configuration"
$JAVA_HOME/bin/java -version

echo "Checking EC2 CLI has been properly installed"
which ec2-describe-regions
ec2-describe-regions -O $access_key -W $secret_key --region $region

echo "Downloading machine image"
wget http://tinycorelinux.net/6.x/x86_64/release/TinyCorePure64-6.4.1.iso
export LOCAL_DISK_IMAGE_PATH=$PWD/TinyCorePure64-6.4.1.iso

echo "Running integration tests"

pushd builder-src > /dev/null
  . .envrc
  # TODO: re-enable errcheck (need to resolve errors found when `go get`ing)
  # go get github.com/kisielk/errcheck
  # errcheck light-stemcell-builder/...
  go test -v -timeout 1h30m light-stemcell-builder/...
popd
