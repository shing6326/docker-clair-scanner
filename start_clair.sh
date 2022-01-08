#!/bin/sh

while ! pg_isready -U postgres -h 127.0.0.1; do
  sleep 1
done

/clair -config=/config/config.yaml
