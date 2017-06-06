#!/bin/sh -x

RESOURCE_GROUP=$1

az group create -n $1 -l 'westus'
az group deployment create -g $RESOURCE_GROUP --template-file ./mainTemplate.json --parameters @./mainTemplate.parameters.json