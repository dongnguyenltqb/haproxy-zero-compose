### ZERO Downtime deployment with HA Proxy.

1. **Requirement**

   - Service need to tell proxy that they are going to down and all the response must be sent before the process was exited, remember to handle `SIGTERM` by docker-compose. For example, application will stop listening on registered port and return 503 for incoming request.
   - In HA Proxy, need to configure retry request to another server if target server goes down.
   - There are more than 2 service instance to handle request.

2. **Deployment step**

   - Stop one instance
   - Deploy another version of stopped instance
   - Start this instance
   - Wait for this instance warn up and receiving traffic
   - Do similar step for the other.

3. **Demo check**

   - start project

     ```shell
     docker-compose up -d
     docker-compose up --build --force-recreate -d haproxy
     ```

   - send request

     ```shell
     hey -n 200000 -c 200 -t 100 http://localhost:8785/cms
     ```

   - deploy service

     ```
     docker-compose stop static_a
     docker-compose up --build -d static_a
     sleep 10
     docker-compose stop static_b
     docker-compose up --build -d static_b

     ```

   - check the test result
