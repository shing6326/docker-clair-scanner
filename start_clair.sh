#!/bin/sh

while ! pg_isready; do
  sleep 1
done

/clair -config=/config/config.yaml
