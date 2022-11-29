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
{https://facsiaginsa.com/redis/setup-redis-ha-using-sentinel}
###  Setup High Availability Redis using Sentinel
____________              ____________
      |            |            |            |
      |   redis1   |            |   redis2   |
      |  sentinel1 |------------|  sentinel2 |
      |____________|     |      |____________|
          master         |          replica
                    _____|______
                   |            |
                   |   redis3   |
                   |  sentinel3 |
                   |____________|
                      replica
--------------------------------------
IP Master : 172.16.16.101
IP Replica: 172.16.16.102
IP Replica: 172.16.16.103

dnf install redis

### Setup Redis Master
vi /etc/redis/redis.conf 
'
bind 0.0.0.0
requirepass "<your-password>"  // change the password
masterauth "<your-password>"   // change the password
'
## Change <your-password> to use your own password, and you must use the same password for requirepass and masterauth on all 3 redis machines. The configuration bind 0.0.0.0 is needed so the redis can be accessed from other machine.

systemctl restart redis 


####### Setup Redis Replica
vi /etc/redis/redis.conf 
'
bind 0.0.0.0
requirepass "<your-password>"  // change the password
replicaof 192.168.5.100 6379
masterauth "<your-password>"   // change the password
'
## Change <your-password> to use your own password, and you must use the same password for requirepass and masterauth on all 3 redis machine.
## Notice that the difference between redis master and replica is just one configuration line: replicaof 192.168.5.100 6379. You can provide you
systemctl restart redis 


#####Checking Master - Replica
#You can check them by set some key in the redis master (in my case is redis1), and then the key should be available in the redis replica (in my case is redis2 & redis3).
#Go to your master redis and run this command to enter the redis console

master$redis-cli

#Authenticate yourself using the requirepass password you set in the redis configuration

auth <your-password>
#Set sample key value pair to redis

SET foo bar

#Now, go to your replica redis and run this command to enter the redis console

Replica$ redis-cli

#Authenticate yourself using the requirepass password you set in the redis configuration

auth <your-password>

#Get the sample key you previously set on the master redis
$GET foo
#You will get bar

#This is confirming that when you write on the master redis, it will be pushed to the replica redis.



##### Configure Redis Sentinel
#Right now you have master - replica setup, but it is not enough, because when the master die, the replica not automatically replace the master. This is what the Sentinels are for.

#First, create sentinel configuration file

nano /etc/redis/sentinel.conf
Copy paste this script on sentinel1
'
daemonize yes
port 26379
bind 0.0.0.0
supervised systemd
pidfile "/run/redis/redis-sentinel.pid"
logfile "/var/log/redis/sentinel.log"
sentinel monitor mymaster 172.16.16.101 6379 2   ### verify number of sentinal for switch to each slave, if one replica choose (1), if replica 2 choose (2)
sentinel auth-pass mymaster <your-password>
sentinel down-after-milliseconds mymaster 5000
sentinel failover-timeout mymaster 60000
sentinel parallel-syncs mymaster 1
'
Copy paste this script on sentinel2 & sentinel3
'
daemonize yes
port 26379
bind 0.0.0.0
supervised systemd
pidfile "/run/redis/redis-sentinel.pid"
logfile "/var/log/redis/sentinel.log"
sentinel monitor mymaster 192.168.5.100 6379 2
sentinel auth-pass mymaster <your-password>
sentinel down-after-milliseconds mymaster 5000
sentinel failover-timeout mymaster 60000
sentinel parallel-syncs mymaster 1
'
Change the <your-password> with your requirepass password on redis configuration.

Notice that the difference between sentinel1 and other sentinel is just the ip of redis master. Because the sentinel1 is in the same machine as redis master, we can use 127.0.0.1 as redis master ip. For other sentinels, we must define the master ip that is 192.168.5.100.

After that, change the ownership of the file to redis

chown redis:redis /etc/redis/sentinel.conf



#Start the sentinel service
systemctl restart redis-sentinel

#Enable the service so the sentinel will start on boot

systemctl enable redis-sentinel
#To see weather the sentinel is configured correctly, look at the sentinel1 log file

tail -f /var/log/redis/sentinel.log
#You should see something like this

26139:X 02 Oct 2021 07:28:35.735 # +monitor master mymaster 127.0.0.1 6379 quorum 2
26139:X 02 Oct 2021 07:29:00.775 # +sdown master mymaster 127.0.0.1 6379
26139:X 02 Oct 2021 07:33:01.451 * +sentinel sentinel 8c0f32f16c057d906d18a15c6abea99d73ec509e 192.168.5.101 26379 @ mymaster 127.0.0.1 6379
26139:X 02 Oct 2021 07:33:30.524 * +sentinel sentinel bfc1a7ec8abbdf0f31c5d78737ba12f69c0e7fd7 192.168.5.102 26379 @ mymaster 127.0.0.1 6379
The sentinel1 will monitor the redis master on 127.0.0.1 and also detect other sentinel from other machine. In my case it is from 192.168.5.101 and 192.168.5.102.

Now, if you kill the master machine, the sentinels will choose and replace the master with one of the replica automatically.




=====================================================================================
=====================================================================================
=====================================================================================
{https://youtu.be/ZulHGH4io5E}

master redis port 10.128.0.2 (6379,26379)

slave   redis port  (6379,26379)

ssh passwordless

using hostname on all VMs
----------------------------------------

master$ tar -xvf redis-stable-tar.gz
master$ cd redis-stable
ls -l 
'redis.conf  sentinel.conf'

master$ make
master$ vi redis.conf
'
bind IP
logfile "/tmp/redis.log"
'
$vi sentinel.conf 
'
bind 10.128.0.2 
logfile "/tmp/sentinel.log"
sentinel monitor mymaster 10.128.0.2 637 2
'
# copy redis-stable to two nodes
slave1$ vi redis-stable/redis.conf
'
bind 10.128.0.4
replicaof 10.128.0.2 6379
'
slave1$ vi redis-stable/sentinel.conf 
'
bind 10.128.0.4
'


slave2
$ vi redis.config 
'
bind 10.128.0.5
replicaof 10.128.0.2 6379
'
vi sentinel.conf 
'
bind 10.128.0.5
'

------------------------------------------------------
master$ redis-server redis-stable/redis.conf &
master$ redis-sentinel redis-stable/sentinel.conf  &
master$ tail -f /tmp/redis.log 
master$ tail -f /tmp/sentinel.log 

s
lave1$ redis-server redis-stable/redis.conf &
slave1$ redis-sentinel redis-stable/sentinel.conf &

slave2$ redis-server redis-stable/redis.conf &
       $ redis-sentinel redis-stable/sentinel.conf 


slave3$ redis-cli -h 10.128.0.2 -p 6379

10.128.0.2:6379> dbsize
10.128.0.2:6379> keys *
               > exit 

slave3$ redis-cli -h 10.128.0.4 -p 6379
-----------
## shutdown service on master node
master$ redis-cli -h 10.128.0.2 -p 6379 shutdown

switch to slave1 is master 

master$ redis-server redis-stable/redis.conf &
master is slave and slave1 still master 
-========================================













======================================================
# redis.conf
port 7000
cluster-enabled yes
cluster-config-file nodes.conf
cluster-node-timeout 5000
appendonly yes
------------------------------
mkdir 7000 7001 7002 7003 7004 7005 7006 7007
cp redis.conf  7000/redis.conf
cp redis.conf  7001/redis.conf
cp redis.conf  7002/redis.conf
cp redis.conf  7003/redis.conf
cp redis.conf  7004/redis.conf
cp redis.conf  7005/redis.conf
cp redis.conf  7006/redis.conf
cp redis.conf  7007/redis.conf

# change port in each file 
=================================================

=================================