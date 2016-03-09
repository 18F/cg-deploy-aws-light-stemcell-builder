#!/usr/bin/env bash

set -ex -o pipefail

my_dir="$( cd $(dirname $0) && pwd )"
release_dir="$( cd ${my_dir} && cd ../.. && pwd )"

source ${release_dir}/ci/tasks/utils.sh

: ${ami_description:?}
: ${ami_virtualization_type:?}
: ${ami_visibility:?}
: ${us_ami_region:?}
: ${us_ami_access_key:?}
: ${us_ami_secret_key:?}
: ${us_ami_bucket_name:?}
: ${us_ami_destinations:?}
: ${cn_ami_region:?}
: ${cn_ami_access_key:?}
: ${cn_ami_secret_key:?}
: ${cn_ami_bucket_name:?}

stemcell_path=${PWD}/input-stemcell/*.tgz
output_path=${PWD}/light-stemcell/

echo "Building light stemcell"

export CONFIG_PATH=${PWD}/config.json

cat > $CONFIG_PATH << EOF
{
  "ami_configuration": {
    "description":          "$ami_description",
    "virtualization_type":  "$ami_virtualization_type",
    "visibility":           "$ami_visibility"
  },
  "ami_regions": [
    {
      "name":               "$us_ami_region",
      "credentials": {
        "access_key":       "$us_ami_access_key",
        "secret_key":       "$us_ami_secret_key"
      },
      "bucket_name":        "$us_ami_bucket_name",
      "destinations":       $us_ami_destinations
    },
    {
      "name":               "$cn_ami_region",
      "credentials": {
        "access_key":       "$cn_ami_access_key",
        "secret_key":       "$cn_ami_secret_key"
      },
      "bucket_name":        "$cn_ami_bucket_name"
    }
  ]
}
EOF

echo "Configuration:"
cat $CONFIG_PATH

extracted_stemcell_dir=${PWD}/extracted-stemcell
mkdir -p ${extracted_stemcell_dir}
tar -C ${extracted_stemcell_dir} -xf ${stemcell_path}
tar -xf ${extracted_stemcell_dir}/image

original_stemcell_name="$(basename ${stemcell_path})"
light_stemcell_name="light-${original_stemcell_name}"

if [ "${ami_virtualization_type}" = "hvm" ]; then
  light_stemcell_name="${light_stemcell_name/xen/xen-hvm}"
fi

# convert raw format to smaller stream optimized format to reduce upload time
raw_stemcell_image=${PWD}/root.img
raw_stemcell_volume_size_in_gb=$(du --apparent-size --block-size=1G ${raw_stemcell_image} | cut -f 1)
optimized_stemcell_image=${PWD}/tiny.vmdk
qemu-img convert -O vmdk -o subformat=streamOptimized ${raw_stemcell_image} ${optimized_stemcell_image}
stemcell_manifest=${extracted_stemcell_dir}/stemcell.MF

pushd ${release_dir} > /dev/null
  . .envrc
  # Make sure we've closed the manifest file before writing to it
  go run src/light-stemcell-builder/main.go \
    -c $CONFIG_PATH \
    --image ${optimized_stemcell_image} \
    --format vmdk \
    --volume-size ${raw_stemcell_volume_size_in_gb} \
    --manifest ${stemcell_manifest} \
    | tee tmp-manifest

  mv tmp-manifest ${stemcell_manifest}

popd

> ${extracted_stemcell_dir}/image
tar -C ${extracted_stemcell_dir} -czf ${output_path}/${light_stemcell_name} .
tar -tf ${output_path}/${light_stemcell_name}
