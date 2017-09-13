#!/bin/bash
DIR=$(pwd)
source bash_alias

cd $DIR/terraform/network && tf_destroy -force

cd $DIR/terraform/bastion && tf_destroy -force

cd $DIR/terraform/vpc && tf_destroy -force