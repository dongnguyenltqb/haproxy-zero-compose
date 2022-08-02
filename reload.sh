#!/bin/bash
docker compose exec -iT haproxy sh <<EOT
cat /var/run/haproxy.pid | xargs kill -SIGUSR2
EOT