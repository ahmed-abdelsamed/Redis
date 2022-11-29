
____________              ____________
      |            |            |            |
      |   redis1   |            |   redis2   |
      |  sentinel1 |------------|  sentinel2 |
      |____________|            |____________|
          master                   replica
                   
### Generate SSL certificate

openssl genrsa -out rootCA.key 2048
openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 1024 -out rootCA.pem 
openssl genrsa -out redis.key 2048
openssl req -new -key redis.key -out redis.csr 
openssl x509 -req -in redis.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial -out redis.crt -days 500 -sha256 
cat redis.key redis.crt > redis.pem 


### Redis with TLS


Redis.conf  (master)
'
bind 0.0.0.0
protected-mode yes
tcp-backlog 511
timeout 0
tcp-keepalive 300
port 0
tls-port 6379
tls-cert-file /etc/redis/tls/redis.pem
tls-key-file /etc/redis/tls/redis.pem
tls-ca-cert-file /etc/redis/tls/redis.pem
tls-auth-clients no
tls-replication yes
daemonize no
pidfile /var/run/redis_6379.pid
loglevel notice
logfile /var/log/redis/redis.log
masterauth password
requirepass password
'
---------------------------------------------
sentinel.conf (master)
'
sentinel announce-hostnames no
daemonize no
port 26379
bind 0.0.0.0
supervised systemd
pidfile "/run/redis/redis-sentinel.pid"
logfile "/var/log/redis/sentinel.log"
sentinel monitor mymaster 172.16.16.101 6379 1
sentinel auth-pass mymaster password
sentinel down-after-milliseconds mymaster 5000
sentinel failover-timeout mymaster 60000

tls-port 26379
tls-replication yes
port 0
tls-cert-file /etc/redis/tls/redis.pem
tls-key-file /etc/redis/tls/redis.pem
tls-ca-cert-file /etc/redis/tls/redis.pem
'
------------------------------------------------
redis.conf (slave)
'
bind 0.0.0.0
protected-mode yes
port 0
tls-port 6379
tls-cert-file /etc/redis/tls/redis.pem
tls-key-file /etc/redis/tls/redis.pem
tls-ca-cert-file /etc/redis/tls/redis.pem
daemonize no
replicaof 172.16.16.101 6379
masterauth password
requirepass password
'

sentinel.conf (slave)
'
sentinel announce-hostnames no

daemonize no
port 26379
bind 0.0.0.0
supervised systemd

sentinel monitor mymaster 172.16.16.101 6379 2
sentinel auth-pass mymaster password
sentinel down-after-milliseconds mymaster 5000
sentinel failover-timeout mymaster 60000

tls-port 26379
tls-replication yes
port 0
tls-cert-file /etc/redis/tls/redis.pem
tls-key-file /etc/redis/tls/redis.pem
tls-ca-cert-file /etc/redis/tls/redis.pem
'


=============================================================================================
===========================================================================================








