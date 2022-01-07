#!/bin/sh

while ! pg_isready --username=postgres; do 
  sleep 1
done

/clair -config=/config/config.yaml
