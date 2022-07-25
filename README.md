### ZERO Downtime deployment with HA Proxy.

1. **Blue/Green deployment**

   - Blue green deployment is an application release model that gradually transfers user traffic from a previous version of an app or microservice to a nearly identical new release—both of which are running in production.

   - The old version can be called the blue environment while the new version can be known as the green environment. Once production traffic is fully transferred from blue to green, blue can standby in case of rollback or pulled from production and updated to become the template upon which the next update is made.

2. **Requirement**

   - Service need to tell proxy that they are going to down and all the response must be sent before the process was exited, remember to handle `SIGTERM` by docker-compose. For example, application will stop listening on registered port and return 503 for incoming request.
   - In HA Proxy, need to configure retry request to another server if target server goes down.
   - There are more than 2 service instance to handle request.

3. **Deployment step**

   - Stop one instance
   - Deploy another version of stopped instance
   - Start this instance
   - Wait for this instance warn up and receiving traffic
   - Do similar step for the other.

4. **Demo check**

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
      ./deploy.sh
     ```

   - check the test result
