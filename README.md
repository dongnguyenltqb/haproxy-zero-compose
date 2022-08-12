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

5. **Very graceful deploy**

   - Get back-end health status before up/down
   - Make sure all request was processed before shutdown the server
   - Sample code

     ```bash
     #!/bin/bash
     function forwardTo(){
        echo "set map /home/dong/code/learn-haproxy/hosts.map STATIC $1" | socat stdio tcp4-connect:127.0.0.1:9000
     }

     function readyToDown(){
        serverName=$1
        ok="false"
        while [[ $ok == "false" ]];
        do
           sleep 1
           count=$(echo "show servers conn $serverName $" | socat stdio tcp4-connect:127.0.0.1:9000 | sed -n 2p | cut -d " " -f 7)
           echo "current connection on $serverName: ${count}"
           if [[ $count == "0" ]]; then
                 ok="true"
           fi;
        done

     }

     function waitItUp(){
        serverName=$1
        itUp="false"
        while [[ $itUp == "false" ]];
        do
           echo "wait for $serverName up"
           status=$(echo "show stat" | socat stdio tcp4-connect:127.0.0.1:9000 | cut -d "," -f 2,18 | column -s, -t | grep $serverName | awk "{print \$2}")
           echo "$serverName status: $status"
           if [[ $status != "UP" ]]; then
                 sleep 1
           else
                 itUp="true"
           fi
        done
     }

     echo "deploying new version to green"
     waitItUp green

     echo "forward all traffic to green"
     forwardTo green

     echo "make sure all request was processed by s1 before deploying"
     readyToDown blue

     echo "ready to deploy blue (update new version)"
     echo "deployed blue"
     echo "wait for blue to up"
     waitItUp blue
     forwardTo blue

     readyToDown green

     echo "done"
     ```
