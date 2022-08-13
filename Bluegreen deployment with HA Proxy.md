# Blue/green deployment with HA Proxy.

First, let finding what is blue/green deployment.

A blue/green deployment is a deployment strategy in which you create two separate, but identical environments. One environment (blue) is running the current application version and one environment (green) is running the new application version. Using a blue/green deployment strategy increases application availability and reduces deployment risk by simplifying the rollback process if a deployment fails. Once testing has been completed on the green environment, live application traffic is directed to the green environment and the blue environment is deprecated.

When you deploy out service, it’s usually stay behind a reverse proxy. Nginx , ha proxy is the popular choice.

But why i do not chose nginx instead of haproxy.

The first reason is nginx did not allow us to interact with run time easily, the only way is update nginx configuration and use reload function ( `nginx -s reload`), it is hard to populate upstream health status, metrics, route traffic to another upstream on the fly.

Ha proxy is an old product, a 22 years old proxy, come with a lot of feature and allow us to interact with runtime easier. But it will not easy to learn at the first time due to a very long documentation, the official document format is old style,hard to read, but luckily we have another one provide a beautiful documentation. The official blog page still have some introduction for their feature.

[Blog - HAProxy TechnologiesWith HAProxy situated in front of their servers, many people leverage it as a frontline component for enabling extra…www.haproxy.com](https://www.haproxy.com/blog/)

[HAProxy version 2.6-dev3 - Starter GuideQuick introduction to load balancing and load balancerscbonte.github.io](https://cbonte.github.io/haproxy-dconv/2.6/intro.html)

Another thing is built-in admin dashboard, it is simple but very useful, provide enough information about the service behind.

![img](https://miro.medium.com/max/875/1*g7KGtKwbZL0QUw5gwuBy1A.png)



So, let take a fast look into documentation before going down, i will show how i usually release my application.

If you have not haproxy installed on current machine, follow the instruction from.

https://github.com/haproxy/haproxy/blob/master/INSTALL



Let have a very simple back end with only one application stand behind a haproxy service. Proxy server listen on port `8085` and two docker application listen on port `3000`, `4000`, it’s just echo server.

```
version: "3.9"services:
  blue:
    image: ealen/echo-server
    ports:
      - 3000:3000
    environment:
      PORT: 3000
    networks:
      - haproxy
  green:
    image: ealen/echo-server
    ports:
      - 4000:4000
    environment:
      PORT: 4000
    networks:
      - haproxynetworks:
  haproxy:
    driver: bridge
```

Blue application is running and handle traffic come from port 3000 while Green application is stopped.

![img](https://miro.medium.com/max/875/1*pNUwZfNdfuf7JNkmKn0FJQ.png)

Haproxy process start with some arguments and a config file. Let take a look at the below configuration file.

```
global
    maxconn 8192
    log stdout format raw daemon debug
    stats socket ipv4@127.0.0.1:9000 level admin
    stats timeout 2mresolvers local
    nameserver ns1 127.0.0.53:53
    nameserver ns2 192.168.1.1:53
    hold valid 5s
    resolve_retries 3
    timeout retry 1s
    timeout resolve 1sdefaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    http-reuse aggressive
    timeout connect 2s
    timeout client 1m
    timeout server 5sfrontend igw
    bind *:8785
    mode http
    stats enable
    monitor-uri /haproxy-status
    stats uri /admin
    stats auth admin:admin
    stats refresh 5s
    default_backend DEFAULT
    option forwardfor    use_backend %[str(SIMPLE_SERVICE),map(/home/dong/code/learn-haproxy/hosts.map)]backend blue
    mode http
    option http-keep-alive
    timeout http-keep-alive 10m
    timeout connect 10s
    balance roundrobin
    option httpchk
    option redispatch
    retries 1000
    retry-on all-retryable-errors
    http-check send meth GET  uri /
    server blue localhost:3000 maxconn 10 check inter 2s  fall 2  rise 2 slowstart 5000 resolvers local init-addr nonebackend green
    mode http
    option http-keep-alive
    timeout http-keep-alive 10m
    timeout connect 10s
    balance roundrobin
    option httpchk
    option redispatch
    retries 1000
    retry-on all-retryable-errors
    http-check send meth GET  uri /
    server green localhost:4000 maxconn 10 check inter 2s  fall 2  rise 2 slowstart 5000 resolvers local init-addr nonebackend DEFAULT
    http-request set-log-level silent
    http-request return status 404 content-type "text/html" string "Default backend"
```



You can see i define a `frontend` , 3 `backend` section. Front-end section is define which port/protocol haproxy will listen on, in this case, port is `8785` and protocol is `http` . In each `backend` i define which service belong to this `backend`, port, health check configuration, you can check these thing on the documentation i listed above.

Beside that in `global` section, you can see i define a port `9000` , it’s the port for us to interact with runtime via TCP.

A special point is `use_backend` directive in the `frontend` section, haproxy allow us create a map (key, value) to store information about which backend will handle the request depends on our configuration, with every imcoming request, haproxy will lookup to this map and find out which back end will handle this request.

I define a key `SIMPLE_SERIVE`, the value is the name of the `backend` server which will handle request from `frontend igw` .

```
use_backend %[str(SIMPLE_SERVICE),map(/home/dong/code/learn-haproxy/hosts.map)]
```

A good new is haproxy allow us to modify map value with runtime api, this is amazing feature that help us control out proxy.

For example we can call runtime api to forward traffic to another back end if we can, simply edit that map value.

So let start out haproxy process. Remember we have a back end “Blue” is listening for incoming request while “Green” back end is down.

```
haproxy -W -f haproxy.cfg -p haproxy.pid
```



After running this command, haproxy was running.

```
➜  learn-haproxy haproxy -W -f haproxy.cfg -p haproxy.pid
[NOTICE]   (41701) : New worker (41703) forked
[NOTICE]   (41701) : Loading success.
[WARNING]  (41703) : blue/blue changed its IP from (none) to ::1 by local/ns1.
blue/blue changed its IP from (none) to ::1 by local/ns1.
[WARNING]  (41703) : Server blue/blue ('localhost') is UP/READY (resolves again).
Server blue/blue ('localhost') is UP/READY (resolves again).
[WARNING]  (41703) : Server blue/blue administratively READY thanks to valid DNS answer.
Server blue/blue administratively READY thanks to valid DNS answer.
[WARNING]  (41703) : green/green changed its IP from (none) to ::1 by DNS cache.
green/green changed its IP from (none) to ::1 by DNS cache.
[WARNING]  (41703) : Server green/green ('localhost') is UP/READY (resolves again).
Server green/green ('localhost') is UP/READY (resolves again).
[WARNING]  (41703) : Server green/green administratively READY thanks to valid DNS answer.
Server green/green administratively READY thanks to valid DNS answer.
[WARNING]  (41703) : Server green/green is DOWN, reason: Layer4 connection problem, info: "Connection refused", check duration: 0ms. 0 active and 0 backup servers left. 0 sessions active, 0 requeued, 0 remaining in queue.
Server green/green is DOWN, reason: Layer4 connection problem, info: "Connection refused", check duration: 0ms. 0 active and 0 backup servers left. 0 sessions active, 0 requeued, 0 remaining in queue.
[ALERT]    (41703) : backend 'green' has no server available!
backend green has no server available!
[WARNING]  (41703) : Server blue/blue is UP. 1 active and 0 backup servers online. 0 sessions requeued, 0 total in queue.
Server blue/blue is UP. 1 active and 0 backup servers online. 0 sessions requeued, 0 total in queue.
```

You can ignore some verbose message now, it’s just some event displayed from health checking, dns discovery.

Go to http://localhost:8785/admin to watch the current state. From the configuration, the admin user/password is `admin/admin` .



![img](https://miro.medium.com/max/875/1*fdVUYnDNtFdoJSP2obmDhQ.png)

So let send a request to `http://localhost:8785` .

```
➜  learn-haproxy curl localhost:8785
{"host":{"hostname":"localhost","ip":"::ffff:172.26.0.1","ips":[]},"http":{"method":"GET","baseUrl":"","originalUrl":"/","protocol":"http"},"request":{"params":{"0":"/"},"query":{},"cookies":{},"body":{},"headers":{"host":"localhost:8785","user-agent":"curl/7.81.0","accept":"*/*","x-forwarded-for":"127.0.0.1"}},"environment":{"PATH":"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin","HOSTNAME":"df2a65d14f4b","PORT":"3000","NODE_VERSION":"16.16.0","YARN_VERSION":"1.22.19","HOME":"/root"}}%                                                       
➜  learn-haproxy
```

From the haproxy stdout, you can see that “Blue” handled out request.

```
127.0.0.1:39032 [13/Aug/2022:17:02:40.664] igw blue/blue 0/0/0/1/1 200 689 - - ---- 1/1/0/0/0 0/0 "GET / HTTP/1.1"
```

Let deploy new version for “Green”, to be simple i just re-create this.

```
docker compose up -d --build --force-recreate green
```

Next step, we verify “Green” is up and ready to handle incoming request. You can see on dashboard or send a message to runtime using port 9000.

```
echo "show stat" | socat stdio tcp4-connect:127.0.0.1:9000
```

You will received a lot of stat but let choose only `status` field.

```
➜  learn-haproxy echo "show stat" | socat stdio tcp4-connect:127.0.0.1:9000
# pxname,svname,qcur,qmax,scur,smax,slim,stot,bin,bout,dreq,dresp,ereq,econ,eresp,wretr,wredis,status,weight,act,bck,chkfail,chkdown,lastchg,downtime,qlimit,pid,iid,sid,throttle,lbtot,tracked,type,rate,rate_lim,rate_max,check_status,check_code,check_duration,hrsp_1xx,hrsp_2xx,hrsp_3xx,hrsp_4xx,hrsp_5xx,hrsp_other,hanafail,req_rate,req_rate_max,req_tot,cli_abrt,srv_abrt,comp_in,comp_out,comp_byp,comp_rsp,lastsess,last_chk,last_agt,qtime,ctime,rtime,ttime,agent_status,agent_code,agent_duration,check_desc,agent_desc,check_rise,check_fall,check_health,agent_rise,agent_fall,agent_health,addr,cookie,mode,algo,conn_rate,conn_rate_max,conn_tot,intercepted,dcon,dses,wrew,connect,reuse,cache_lookups,cache_hits,srv_icur,src_ilim,qtime_max,ctime_max,rtime_max,ttime_max,eint,idle_conn_cur,safe_conn_cur,used_conn_cur,need_conn_est,uweight,agg_server_check_status,-,ssl_sess,ssl_reused_sess,ssl_failed_handshake,h2_headers_rcvd,h2_data_rcvd,h2_settings_rcvd,h2_rst_stream_rcvd,h2_goaway_rcvd,h2_detected_conn_protocol_errors,h2_detected_strm_protocol_errors,h2_rst_stream_resp,h2_goaway_resp,h2_open_connections,h2_backend_open_streams,h2_total_connections,h2_backend_total_streams,h1_open_connections,h1_open_streams,h1_total_connections,h1_total_streams,h1_bytes_in,h1_bytes_out,h1_spliced_bytes_in,h1_spliced_bytes_out,
igw,FRONTEND,,,0,3,8192,3,243,2067,0,0,0,,,,,OPEN,,,,,,,,,1,2,0,,,,0,0,0,1,,,,0,3,0,0,0,0,,0,1,3,,,0,0,0,0,,,,,,,,,,,,,,,,,,,,,http,,0,1,3,0,0,0,0,,,0,0,,,,,,,0,,,,,,,-,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,3,234,2082,0,0,
blue,blue,0,0,0,1,10,3,243,2067,,0,,0,0,0,0,UP,1,1,0,0,1,547,0,,1,3,1,,3,,2,0,,1,L7OK,200,2,0,3,0,0,0,0,,,,3,0,0,,,,,497,,,0,0,1,1,,,,Layer7 check passed,,2,2,3,,,,[::1]:3000,,http,,,,,,,,0,3,0,,,0,,0,0,1,1,0,0,0,0,1,1,,-,0,0,0,,,,,,,,,,,,,,,,,,,,,,
blue,BACKEND,0,0,0,1,1,3,243,2067,0,0,,0,0,0,0,UP,1,1,0,,1,552,0,,1,3,0,,3,,1,0,,1,,,,0,3,0,0,0,0,,,,3,0,0,0,0,0,0,497,,,0,0,1,1,,,,,,,,,,,,,,http,roundrobin,,,,,,,0,3,0,0,0,,,0,0,1,1,0,,,,,1,0,-,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,278,278,164954,10493,0,0,
green,green,0,0,0,0,10,0,0,0,,0,,0,0,0,0,DOWN,1,1,0,1,2,551,551,,1,4,1,,0,,2,0,,0,L4CON,,0,0,0,0,0,0,0,,,,0,0,0,,,,,-1,Connection refused,,0,0,0,0,,,,Layer4 connection problem,,2,2,0,,,,[::1]:4000,,http,,,,,,,,0,0,0,,,0,,0,0,0,0,0,0,0,0,1,1,,-,0,0,0,,,,,,,,,,,,,,,,,,,,,,
green,BACKEND,0,0,0,0,1,0,0,0,0,0,,0,0,0,0,DOWN,0,0,0,,2,551,551,,1,4,0,,0,,1,0,,0,,,,0,0,0,0,0,0,,,,0,0,0,0,0,0,0,-1,,,0,0,0,0,,,,,,,,,,,,,,http,roundrobin,,,,,,,0,0,0,0,0,,,0,0,0,0,0,,,,,0,0,-,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,276,276,0,0,0,0,
DEFAULT,BACKEND,0,0,0,0,820,0,0,0,0,0,,0,0,0,0,UP,0,0,0,,0,552,,,1,5,0,,0,,1,0,,0,,,,0,0,0,0,0,0,,,,0,0,0,0,0,0,0,-1,,,0,0,0,0,,,,,,,,,,,,,,http,roundrobin,,,,,,,0,0,0,0,0,,,0,0,0,0,0,,,,,0,0,-,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
```

Only get status field from output.

```
➜  learn-haproxy echo "show stat" | socat stdio tcp4-connect:127.0.0.1:9000 | cut -d "," -f 2,18 | column -s, -t | grep green | awk "{print \$2}"
DOWN
➜  learn-haproxy
```

Wait a bit, after “Green” passed health check, you will see it `UP` .

```
➜  learn-haproxy echo "show stat" | socat stdio tcp4-connect:127.0.0.1:9000 | cut -d "," -f 2,18 | column -s, -t | grep green | awk "{print \$2}"
UP
➜  learn-haproxy
```

Next step, forward all incoming traffic to `Green` .

```
echo "set map /home/dong/code/learn-haproxy/hosts.map SIMPLE_SERVICE green" | socat stdio tcp4-connect:127.0.0.1:9000
```

Send a request to `http://localhost:8785` and see haproxy stdout, you will see `Green` handle out request.

```
127.0.0.1:39054 [13/Aug/2022:17:16:15.091] igw green/green 0/0/0/2/2 200 689 - - ---- 3/3/0/0/0 0/0 "GET / HTTP/1.1"
```

So let write a script, we will verify health status up g`reen` when deploying it, wait `green` to up then forwarding traffic to `green` .

The `waitItUp` function receive server name from argument( `green` or `blue` ), call runtime to make sure it is `UP` then stop.

```
function waitItUp(){
    serverName=$1
    itUp="false"
    while [[ $itUp == "false" ]];
    do
        status=$(echo "show stat" | socat stdio tcp4-connect:127.0.0.1:9000 | cut -d "," -f 2,18 | column -s, -t | grep $serverName | awk "{print \$2}")
        echo "$serverName status: $status"
        if [[ $status != "UP" ]]; then
            sleep 1
        else
            itUp="true"
        fi
    done
    echo "$serverName is UP"
}
```

The `forwardTo` function receive server name from argument( `green` or `blue` ), call runtime to set map value, so haproxy will move traffic to another back end.

```
function forwardTo(){
    echo "Forwarding traffic to $1"
    echo "set map /home/dong/code/learn-haproxy/hosts.map SIMPLE_SERVICE $1" | socat stdio tcp4-connect:127.0.0.1:9000
}
```

The `readyToDown` function receive server name from argument( `green` or `blue` ), call runtime to populate the current connection count, if there is 0, we can safely stop this backend.

```
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
    echo "Shutdown server: $serverName"
}
```

Wrap them up into a file called `deploy.sh`

```
#!/bin/bashfunction forwardTo(){
    echo "Forwarding traffic to $1"
    echo "set map /home/dong/code/learn-haproxy/hosts.map SIMPLE_SERVICE $1" | socat stdio tcp4-connect:127.0.0.1:9000
}function readyToDown(){
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
    echo "Shutdown server: $serverName"
}function waitItUp(){
    serverName=$1
    itUp="false"
    while [[ $itUp == "false" ]];
    do
        status=$(echo "show stat" | socat stdio tcp4-connect:127.0.0.1:9000 | cut -d "," -f 2,18 | column -s, -t | grep $serverName | awk "{print \$2}")
        echo "$serverName status: $status"
        if [[ $status != "UP" ]]; then
            sleep 1
        else
            itUp="true"
        fi
    done
    echo "$serverName is UP"
}case $1 in
  release)
    echo "deploying new version to green"
    docker compose up -d --build --force-recreate green
    echo "deployed green"
    waitItUp green
    echo "forward all traffic to green"
    forwardTo green
    ;;
  rollback)
    forwardTo blue
    readyToDown green
    docker compose stop green
    echo "done"
    ;;
  done)
    docker compose up -d --build --force-recreate blue
    sleep 4
    waitItUp blue
    forwardTo blue
    readyToDown green
    docker compose stop green
    ;;
esac
```

To release a application.

```
./deploy release 
```

To rollback deployment

```
./deploy rollback
```

To confirm new version is fine, deploy new version to blue and forward all traffic back end blue, run

```
./deploy done
```

We can try to send request while deploying our service, the `hey` tool is perfect for this purpose.

https://github.com/rakyll/hey

Ready to test our release process.

Start haproxy process, blue container, stop green container.

![img](https://miro.medium.com/max/875/1*3HBWXPh_vwbpZrFcWhvkbA.png)

Start with hey

```
hey -n 100000 -c 100 http://localhost:8785/
```

Run release command

```
./deploy release
```

After the test is done

![img](https://miro.medium.com/max/875/1*rHGaUKtWAtMVpguUFC48LA.png)

You can see that, there is no request with error, we make a `*zero downtime*` deployment.