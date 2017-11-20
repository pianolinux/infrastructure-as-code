#cloud-config
manage_etc_hosts: True
runcmd:
  - sudo mkdir -p /filebeat/config
  - sudo mkdir -p /filebeat/docker
  - sudo mkdir -p /filebeat/secrets
  - sudo mkdir -p /consul/config
  - sudo mkdir -p /consul/secrets
  - sudo mkdir -p /kibana/config
  - sudo mkdir -p /kibana/logs
  - sudo mkdir -p /elasticsearch/secrets
  - sudo mkdir -p /elasticsearch/config
  - sudo mkdir -p /elasticsearch/data
  - sudo mkdir -p /elasticsearch/logs
  - aws s3 cp s3://${bucket_name}/environments/${environment}/elasticsearch/ca_cert.pem /elasticsearch/secrets/ca_cert.pem
  - aws s3 cp s3://${bucket_name}/environments/${environment}/elasticsearch/elasticsearch_cert.pem /elasticsearch/secrets/elasticsearch_cert.pem
  - aws s3 cp s3://${bucket_name}/environments/${environment}/elasticsearch/elasticsearch_key.pem /elasticsearch/secrets/elasticsearch_key.pem
  - aws s3 cp s3://${bucket_name}/environments/${environment}/filebeat/ca_cert.pem /filebeat/secrets/ca_cert.pem
  - aws s3 cp s3://${bucket_name}/environments/${environment}/filebeat/filebeat_cert.pem /filebeat/secrets/filebeat_cert.pem
  - aws s3 cp s3://${bucket_name}/environments/${environment}/filebeat/filebeat_key.pem /filebeat/secrets/filebeat_key.pem
  - aws s3 cp s3://${bucket_name}/environments/${environment}/consul/ca_cert.pem /consul/secrets/ca_cert.pem
  - sudo sysctl -w vm.max_map_count=262144
  - sudo bash -c "echo \"vm.max_map_count=262144\" > /etc/sysctl.d/20-elasticsearch.conf"
  - sudo usermod -aG docker ubuntu
  - sudo chown -R ubuntu.ubuntu /consul
  - sudo chown -R ubuntu.ubuntu /filebeat
  - sudo chown -R ubuntu.ubuntu /kibana
  - sudo chown -R ubuntu:ubuntu /elasticsearch
  - export HOST_IP_ADDRESS=`ifconfig eth0 | grep "inet " | awk '{ print substr($2,6) }'`
  - sudo -u ubuntu docker run -d --name=consul --restart unless-stopped --env HOST_IP_ADDRESS=$HOST_IP_ADDRESS --net=host -v /consul/config:/consul/config -v /consul/secrets:/consul/secrets consul:latest agent -bind=$HOST_IP_ADDRESS -client=$HOST_IP_ADDRESS -node=kibana-$HOST_IP_ADDRESS -retry-join=${consul_hostname} -datacenter=${consul_datacenter} -encrypt=${consul_secret}
  - sudo -u ubuntu docker run -d --name=elasticsearch --restart unless-stopped -p 9200:9200 -p 9300:9300 --ulimit nofile=65536:65536 --ulimit memlock=-1:-1 -e ES_JAVA_OPTS="-Xms512m -Xmx512m -Dnetworkaddress.cache.ttl=1" -e network.publish_host=$HOST_IP_ADDRESS --net=host -v /elasticsearch/config/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml -v /elasticsearch/data:/usr/share/elasticsearch/data -v /elasticsearch/logs:/usr/share/elasticsearch/logs -v /elasticsearch/secrets:/usr/share/elasticsearch/config/secrets docker.elastic.co/elasticsearch/elasticsearch:${elasticsearch_version}
  - sudo -u ubuntu docker run -d --name=kibana --restart unless-stopped -p 5601:5601 --net=host -e SERVER_HOST=$HOST_IP_ADDRESS -e NODE_TLS_REJECT_UNAUTHORIZED=0 -e NODE_EXTRA_CA_CERTS=/elasticsearch/secrets/ca_cert.pem -v /kibana/config/kibana.yml:/usr/share/kibana/config/kibana.yml -v /elasticsearch/secrets:/usr/share/kibana/config/secrets -v /kibana/logs:/usr/share/kibana/logs docker.elastic.co/kibana/kibana:${kibana_version}
  - sudo -u ubuntu docker build -t filebeat:${kibana_version} /filebeat/docker
  - sudo -u ubuntu docker run -d --name=filebeat --restart unless-stopped --net=host -v /filebeat/config/filebeat.yml:/usr/share/filebeat/filebeat.yml -v /filebeat/secrets:/filebeat/secrets -v /var/log/syslog:/var/log/docker filebeat:${filebeat_version}
  - sudo -u ubuntu curl -XPUT --insecure 'https://elastic:changeme@'$HOST_IP_ADDRESS':9200/.kibana/index-pattern/filebeat-*' -d@/kibana-index-patterns/filebeat-index.json
write_files:
  - path: /consul/config/consul.json
    permissions: '0644'
    content: |
        {
          "ca_file": "/consul/secrets/ca_cert.pem",
          "verify_outgoing" : true,
          "enable_script_checks": true,
          "leave_on_terminate": true,
          "dns_config": {
            "allow_stale": true,
            "max_stale": "1s",
            "service_ttl": {
              "*": "5s"
            }
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
  - path: /etc/docker/daemon.json
    permissions: '0644'
    content: |
        {
          "log-driver": "syslog",
          "log-opts": {
            "labels": "${environment},kibana",
            "tag": "{{.ImageName}}/{{.Name}}/{{.ID}}"
          }
        }
  - path: /consul/config/elasticsearch.json
    permissions: '0644'
    content: |
        {
            "services": [{
                "name": "elasticsearch-query",
                "tags": [
                    "https", "query"
                ],
                "port": 9200,
                "checks": [{
                    "id": "1",
                    "name": "Elasticsearch HTTP",
                    "notes": "Use curl to check the web service every 60 seconds",
                    "script": "curl --insecure https://$HOST_IP_ADDRESS:9200 >/dev/null 2>&1",
                    "interval": "60s"
                }]
            },{
                "name": "elasticsearch-index",
                "tags": [
                    "tcp", "index"
                ],
                "port": 9300,
                "checks": [{
                    "id": "1",
                    "name": "Elasticsearch TCP",
                    "notes": "Use nc to check the tcp port every 60 seconds",
                    "script": "nc -zv $HOST_IP_ADDRESS 9300 >/dev/null 2>&1",
                    "interval": "60s"
                }]
            }]
        }
  - path: /consul/config/kibana.json
    permissions: '0644'
    content: |
        {
            "services": [{
                "name": "kibana",
                "tags": [
                    "https", "kibana"
                ],
                "port": 5601,
                "checks": [{
                    "id": "1",
                    "name": "Kibana HTTP",
                    "notes": "Use curl to check the web service every 60 seconds",
                    "script": "curl --insecure https://$HOST_IP_ADDRESS:5601 >/dev/null 2>&1",
                    "interval": "60s"
                }]
            }]
        }
  - path: /kibana/config/kibana.yml
    permissions: '0644'
    content: |
        logging.verbose: false
        logging.quiet: true
        kibana.index: ".kibana"
        kibana.defaultAppId: "discover"
        server.port: 5601
        server.ssl.enabled: true
        server.ssl.key: "/usr/share/kibana/config/secrets/elasticsearch_key.pem"
        server.ssl.certificate: "/usr/share/kibana/config/secrets/elasticsearch_cert.pem"
        server.ssl.certificateAuthorities: ["/usr/share/kibana/config/secrets/ca_cert.pem"]
        elasticsearch.url: "https://${elasticsearch_host}:9200"
        elasticsearch.username: "kibana"
        elasticsearch.password: "changeme"
        elasticsearch.ssl.verificationMode: "certificate"
        elasticsearch.ssl.key: "/usr/share/kibana/config/secrets/elasticsearch_key.pem"
        elasticsearch.ssl.certificate: "/usr/share/kibana/config/secrets/elasticsearch_cert.pem"
        elasticsearch.ssl.certificateAuthorities: ["/usr/share/kibana/config/secrets/ca_cert.pem"]
        xpack.reporting.encryptionKey: "cafebabe"
        xpack.monitoring.elasticsearch.url: "https://${elasticsearch_host}:9200"
        xpack.monitoring.elasticsearch.username: "kibana"
        xpack.monitoring.elasticsearch.password: "changeme"
        xpack.monitoring.elasticsearch.ssl.verificationMode: "certificate"
        xpack.monitoring.elasticsearch.ssl.certificateAuthorities: ["/usr/share/kibana/config/secrets/ca_cert.pem"]
  - path: /filebeat/config/filebeat.yml
    permissions: '0644'
    content: |
        filebeat.prospectors:
        - input_type: log
          paths:
          - /var/log/docker

        output.logstash:
          hosts: ["${logstash_host}:5044"]
          ssl.certificate_authorities: ["/filebeat/secrets/ca_cert.pem"]
          ssl.certificate: "/filebeat/secrets/filebeat_cert.pem"
          ssl.key: "/filebeat/secrets/filebeat_key.pem"
  - path: /elasticsearch/config/elasticsearch.yml
    permissions: '0644'
    content: |
        xpack.security.enabled: true
        xpack.security.http.ssl.enabled: true
        xpack.security.transport.ssl.enabled: true
        xpack.ssl.verification_mode: "certificate"
        xpack.ssl.key: "/usr/share/elasticsearch/config/secrets/elasticsearch_key.pem"
        xpack.ssl.certificate: "/usr/share/elasticsearch/config/secrets/elasticsearch_cert.pem"
        xpack.ssl.certificate_authorities: ["/usr/share/elasticsearch/config/secrets/ca_cert.pem"]
        cluster.name: "${cluster_name}"
        node.master: false
        node.ingest: false
        node.data: false
        network.host: "0.0.0.0"
        network.bind_host: "0.0.0.0"
        http.port: 9200
        transport.tcp.port: 9300
        bootstrap.memory_lock: true
        discovery.zen.ping.unicast.hosts: "${elasticsearch_nodes}"
        discovery.zen.minimum_master_nodes: ${minimum_master_nodes}
