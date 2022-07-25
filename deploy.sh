#!/bin/bash
echo "=> up static b"
docker compose up -d static_b
echo "> wait 20s for static_b to received request"
sleep 20

echo "=> redirect traffic to static b"
docker compose exec -iT haproxy sh <<EOT
echo "set map /hosts.map STATIC STATIC_B" | socat stdio /var/run/haproxy.sock
EOT
echo "=> wait 5s for static_b to received all new request"
sleep 5


echo "=> deploying static_a"
docker compose stop static_a
docker compose up -d --build --force-recreate static_a
echo "=> wait 20s for static_a to up"
sleep 20

echo "=> redirect traffic to static a"
docker compose exec -iT haproxy sh <<EOT
echo "set map /hosts.map STATIC STATIC_A" | socat stdio /var/run/haproxy.sock
EOT

echo "=> stop static_b"
docker compose stop static_b
