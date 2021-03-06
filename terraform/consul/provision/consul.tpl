#cloud-config
manage_etc_hosts: true
manage_resolv_conf: false
runcmd:
  - sudo mkdir -p /filebeat/docker
  - sudo mkdir -p /filebeat/config/secrets
  - sudo mkdir -p /consul/config/secrets
  - aws s3 cp s3://${bucket_name}/environments/${environment}/filebeat/ca_cert.pem /filebeat/config/secrets/ca_cert.pem
  - aws s3 cp s3://${bucket_name}/environments/${environment}/filebeat/filebeat_cert.pem /filebeat/config/secrets/filebeat_cert.pem
  - aws s3 cp s3://${bucket_name}/environments/${environment}/filebeat/filebeat_key.pem /filebeat/config/secrets/filebeat_key.pem
  - aws s3 cp s3://${bucket_name}/environments/${environment}/consul/ca_cert.pem /consul/config/secrets/ca_cert.pem
  - aws s3 cp s3://${bucket_name}/environments/${environment}/consul/server_cert.pem /consul/config/secrets/server_cert.pem
  - aws s3 cp s3://${bucket_name}/environments/${environment}/consul/server_key.pem /consul/config/secrets/server_key.pem
  - sudo usermod -aG docker ubuntu
  - sudo chown -R ubuntu.ubuntu /consul
  - sudo chown -R ubuntu.ubuntu /filebeat
  - export HOST_IP_ADDRESS=`ifconfig eth0 | grep "inet " | awk '{ print substr($2,6) }'`
  - sudo -u ubuntu docker run -d --name=consul --restart unless-stopped --net=host -e HOST_IP_ADDRESS=$HOST_IP_ADDRESS -v /consul/config:/consul/config consul:latest agent -server=true -ui=true -bind=$HOST_IP_ADDRESS -client=$HOST_IP_ADDRESS -node=consul-$HOST_IP_ADDRESS
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
          "cert_file": "/consul/config/secrets/server_cert.pem",
          "key_file": "/consul/config/secrets/server_key.pem",
          "encrypt": "${consul_secret}",
          "retry_join": ["${element(split(",", consul_nodes), 0)}","${element(split(",", consul_nodes), 1)}","${element(split(",", consul_nodes), 2)}"],
          "datacenter": "${consul_datacenter}",
          "bootstrap_expect": ${consul_bootstrap_expect},
          "enable_script_checks": true,
          "leave_on_terminate": true,
          "dns_config": {
            "allow_stale": true,
            "max_stale": "1s",
            "service_ttl": {
              "*": "5s"
            }
          },
          "ports": {
              "https": 8500,
              "http": -1
          },
          "services": [{
              "name": "consul",
              "tags": [
                  "tcp", "dns"
              ],
              "port": 8600,
              "checks": [{
                  "id": "1",
                  "name": "Consul DNS",
                  "notes": "Use nc to check the dns service every 20 seconds",
                  "script": "nc -zv $HOST_IP_ADDRESS 8600 >/dev/null 2>&1",
                  "interval": "20s"
              }]
          }]
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
  - path: /filebeat/config/filebeat.yml
    permissions: '0644'
    content: |
        filebeat.prospectors:
        - input_type: log
          paths:
          - /var/log/syslog
          tags: ["consul","syslog"]
        output.logstash:
          hosts: ["logstash.service.terraform.consul:5044"]
          ssl.certificate_authorities: ["/filebeat/config/secrets/ca_cert.pem"]
          ssl.certificate: "/filebeat/config/secrets/filebeat_cert.pem"
          ssl.key: "/filebeat/config/secrets/filebeat_key.pem"
  - path: /tmp/10-consul
    permissions: '0644'
    content: |
        server=/consul/$HOST_IP_ADDRESS#8600
  - path: /tmp/11-domain
    permissions: '0644'
    content: |
        server=${hosted_zone_dns}
