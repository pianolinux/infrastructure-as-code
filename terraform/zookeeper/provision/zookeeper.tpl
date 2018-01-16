#cloud-config
manage_etc_hosts: True
manage_resolv_conf: false
runcmd:
  - sudo mkdir -p /filebeat/docker
  - sudo mkdir -p /filebeat/config/secrets
  - sudo mkdir -p /consul/config/secrets
  - sudo mkdir -p /zookeeper/logs
  - sudo mkdir -p /zookeeper/data
  - sudo mkdir -p /zookeeper/config
  - aws s3 cp s3://${bucket_name}/environments/${environment}/filebeat/ca_cert.pem /filebeat/config/secrets/ca_cert.pem
  - aws s3 cp s3://${bucket_name}/environments/${environment}/filebeat/filebeat_cert.pem /filebeat/config/secrets/filebeat_cert.pem
  - aws s3 cp s3://${bucket_name}/environments/${environment}/filebeat/filebeat_key.pem /filebeat/config/secrets/filebeat_key.pem
  - aws s3 cp s3://${bucket_name}/environments/${environment}/consul/ca_cert.pem /consul/config/secrets/ca_cert.pem
  - sudo usermod -aG docker ubuntu
  - sudo chown -R ubuntu:ubuntu /consul
  - sudo chown -R ubuntu:ubuntu /filebeat
  - sudo chown -R ubuntu:ubuntu /zookeeper
  - export HOST_IP_ADDRESS=`ifconfig eth0 | grep "inet " | awk '{ print substr($2,6) }'`
  - sudo -u ubuntu docker run -d --name=consul --restart unless-stopped --net=host -e HOST_IP_ADDRESS=$HOST_IP_ADDRESS -v /consul/config:/consul/config consul:latest agent -bind=$HOST_IP_ADDRESS -client=$HOST_IP_ADDRESS -node=zookeeper-$HOST_IP_ADDRESS
  - sudo -u ubuntu docker run -d --name=zookeeper --restart unless-stopped --net=host -p 2181:2181 -v /zookeeper/config/zoo.cfg:/conf/zoo.cfg -v /zookeeper/config/myid:/var/lib/zookeeper/myid -v /zookeeper/data:/var/lib/zookeeper -v /zookeeper/logs:/var/log zookeeper:latest
  - sudo -u ubuntu docker build -t filebeat:${filebeat_version} /filebeat/docker
  - sudo -u ubuntu docker run -d --name=filebeat --restart unless-stopped --net=host --log-driver json-file -v /filebeat/config/filebeat.yml:/usr/share/filebeat/filebeat.yml -v /filebeat/config/secrets:/filebeat/config/secrets -v /var/log/syslog:/var/log/syslog filebeat:${filebeat_version}
  - sudo sed -e 's/$HOST_IP_ADDRESS/'$HOST_IP_ADDRESS'/g' /tmp/10-consul > /etc/dnsmasq.d/10-consul
  - sudo cp /tmp/11-domain /etc/dnsmasq.d/11-domain
  - sudo service dnsmasq restart
write_files:
  - path: /etc/profile.d/variables
    permissions: '0644'
    content: |
        ENVIRONMENT=${environment}
  - path: /consul/config/consul.json
    permissions: '0644'
    content: |
        {
          "ca_file": "/consul/config/secrets/ca_cert.pem",
          "verify_outgoing" : true,
          "enable_script_checks": true,
          "leave_on_terminate": true,
          "encrypt": "${consul_secret}",
          "retry_join": ["${element(split(",", consul_nodes), 0)}","${element(split(",", consul_nodes), 1)}","${element(split(",", consul_nodes), 2)}"],
          "datacenter": "${consul_datacenter}",
          "dns_config": {
            "allow_stale": true,
            "max_stale": "1s",
            "service_ttl": {
              "*": "5s"
            }
          }
        }
  - path: /etc/docker/daemon.json
    permissions: '0644'
    content: |
        {
          "log-driver": "syslog",
          "log-opts": {
            "tag": "Docker/{{.Name}}[{{.ImageName}}]({{.ID}})"
          }
        }
  - path: /filebeat/docker/Dockerfile
    permissions: '0755'
    content: |
        FROM docker.elastic.co/beats/filebeat:${filebeat_version}
        USER root
        RUN useradd -r syslog -u 104
        RUN usermod -aG adm filebeat
        USER filebeat
  - path: /consul/config/zookeeper.json
    permissions: '0644'
    content: |
        {
            "services": [{
                "name": "zookeeper",
                "tags": [
                    "tcp", "zookeeper"
                ],
                "port": 2181,
                "checks": [{
                    "id": "1",
                    "name": "Zookeeper TCP",
                    "notes": "Use nc to check the service every 30 seconds",
                    "script": "echo stat | nc $HOST_IP_ADDRESS 2181 >/dev/null 2>&1",
                    "interval": "30s"
                }]
            }]
        }
  - path: /filebeat/config/filebeat.yml
    permissions: '0644'
    content: |
        filebeat.prospectors:
        - input_type: log
          paths:
          - /var/log/docker
          tags: ["zookeeper","syslog"]
        output.logstash:
          hosts: ["logstash.service.terraform.consul:5044"]
          ssl.certificate_authorities: ["/filebeat/config/secrets/ca_cert.pem"]
          ssl.certificate: "/filebeat/config/secrets/filebeat_cert.pem"
          ssl.key: "/filebeat/config/secrets/filebeat_key.pem"
  - path: /zookeeper/config/zoo.cfg
    permissions: '0644'
    content: |
        tickTime=2000
        dataDir=/var/lib/zookeeper
        clientPort=2181
        initLimit=5
        syncLimit=2
        server.1=${element(split(",", zookeeper_nodes), 0)}:2888:3888
        server.2=${element(split(",", zookeeper_nodes), 1)}:2888:3888
        server.3=${element(split(",", zookeeper_nodes), 2)}:2888:3888
  - path: /zookeeper/config/myid
    permissions: '0644'
    content: |
        ${zookeeper_id}
  - path: /tmp/10-consul
    permissions: '0644'
    content: |
        server=/consul/$HOST_IP_ADDRESS#8600
  - path: /tmp/11-domain
    permissions: '0644'
    content: |
        server=${hosted_zone_dns}
