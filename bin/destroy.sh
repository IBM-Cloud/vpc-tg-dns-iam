#!/bin/bash
set -ex
for d in application2 application1 shared network admin; do
  if [ -d $d ] && [ -e $d/local.env ]; then
    (cd $d && source ./local.env && terraform destroy -auto-approve && rm local.env)
  fi
done
