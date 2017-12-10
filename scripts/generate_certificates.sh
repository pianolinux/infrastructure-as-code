#!/bin/sh

export OUTPUT=$ROOT/secrets

if [ ! -d "$OUTPUT" ]; then

  mkdir -p $OUTPUT

  echo '[extended]\nextendedKeyUsage=serverAuth,clientAuth' > $OUTPUT/openssl.cnf

  ## Create keystore for JWT authentication
  keytool -genseckey -keystore $OUTPUT/keystore-auth.jceks -storetype jceks -storepass secret -keyalg HMacSHA256 -keysize 2048 -alias HS256 -keypass secret
  keytool -genseckey -keystore $OUTPUT/keystore-auth.jceks -storetype jceks -storepass secret -keyalg HMacSHA384 -keysize 2048 -alias HS384 -keypass secret
  keytool -genseckey -keystore $OUTPUT/keystore-auth.jceks -storetype jceks -storepass secret -keyalg HMacSHA512 -keysize 2048 -alias HS512 -keypass secret
  keytool -genkey -keystore $OUTPUT/keystore-auth.jceks -storetype jceks -storepass secret -keyalg RSA -keysize 2048 -alias RS256 -keypass secret -sigalg SHA256withRSA -dname "CN=,OU=,O=,L=,ST=,C=" -validity 360
  keytool -genkey -keystore $OUTPUT/keystore-auth.jceks -storetype jceks -storepass secret -keyalg RSA -keysize 2048 -alias RS384 -keypass secret -sigalg SHA384withRSA -dname "CN=,OU=,O=,L=,ST=,C=" -validity 360
  keytool -genkey -keystore $OUTPUT/keystore-auth.jceks -storetype jceks -storepass secret -keyalg RSA -keysize 2048 -alias RS512 -keypass secret -sigalg SHA512withRSA -dname "CN=,OU=,O=,L=,ST=,C=" -validity 360
  keytool -genkeypair -keystore $OUTPUT/keystore-auth.jceks -storetype jceks -storepass secret -keyalg EC -keysize 256 -alias ES256 -keypass secret -sigalg SHA256withECDSA -dname "CN=,OU=,O=,L=,ST=,C=" -validity 360
  keytool -genkeypair -keystore $OUTPUT/keystore-auth.jceks -storetype jceks -storepass secret -keyalg EC -keysize 256 -alias ES384 -keypass secret -sigalg SHA384withECDSA -dname "CN=,OU=,O=,L=,ST=,C=" -validity 360
  keytool -genkeypair -keystore $OUTPUT/keystore-auth.jceks -storetype jceks -storepass secret -keyalg EC -keysize 256 -alias ES512 -keypass secret -sigalg SHA512withECDSA -dname "CN=,OU=,O=,L=,ST=,C=" -validity 360

  ## Create certificate authority (CA)
  openssl req -new -x509 -keyout $OUTPUT/ca-key -out $OUTPUT/ca-cert -days 365 -passin pass:secret -passout pass:secret -subj "/CN=myself/OU=/O=/L=/ST=/C=/"

  ## Create client keystore
  keytool -noprompt -keystore $OUTPUT/keystore-client.jks -genkey -alias selfsigned -dname "CN=myself,OU=,O=,L=,ST=,C=" -storetype JKS -keyalg RSA -keysize 2048 -validity 999 -storepass secret -keypass secret

  ## Create server keystore
  keytool -noprompt -keystore $OUTPUT/keystore-server.jks -genkey -alias selfsigned -dname "CN=myself,OU=,O=,L=,ST=,C=" -storetype JKS -keyalg RSA -keysize 2048 -validity 999 -storepass secret -keypass secret

  ## Create filebeat keystore
  keytool -noprompt -keystore $OUTPUT/keystore-filebeat.jks -genkey -alias selfsigned -dname "CN=filebeat.service.terraform.consul,OU=,O=,L=,ST=,C=" -storetype JKS -keyalg RSA -keysize 2048 -validity 999 -storepass secret -keypass secret

  ## Create logstash keystore
  keytool -noprompt -keystore $OUTPUT/keystore-kibana.jks -genkey -alias selfsigned -dname "CN=kibana.service.terraform.consul,OU=,O=,L=,ST=,C=" -storetype JKS -keyalg RSA -keysize 2048 -validity 999 -storepass secret -keypass secret

  ## Create logstash keystore
  keytool -noprompt -keystore $OUTPUT/keystore-logstash.jks -genkey -alias selfsigned -dname "CN=logstash.service.terraform.consul,OU=,O=,L=,ST=,C=" -storetype JKS -keyalg RSA -keysize 2048 -validity 999 -storepass secret -keypass secret

  ## Create elasticsearch keystore
  keytool -noprompt -keystore $OUTPUT/keystore-elasticsearch.jks -genkey -alias selfsigned -dname "CN=elasticsearch.service.terraform.consul,OU=,O=,L=,ST=,C=" -storetype JKS -keyalg RSA -keysize 2048 -validity 999 -storepass secret -keypass secret

  ## Create jenkins keystore
  keytool -noprompt -keystore $OUTPUT/keystore-jenkins.jks -genkey -alias selfsigned -dname "CN=jenkins.service.terraform.consul,OU=,O=,L=,ST=,C=" -storetype JKS -keyalg RSA -keysize 2048 -validity 999 -storepass secret -keypass secret

  ## Create consul keystore
  keytool -noprompt -keystore $OUTPUT/keystore-consul.jks -genkey -alias selfsigned -dname "CN=server.terraform.consul,OU=,O=,L=,ST=,C=" -storetype JKS -keyalg RSA -keysize 2048 -validity 999 -storepass secret -keypass secret

  ## Sign client certificate
  keytool -noprompt -keystore $OUTPUT/keystore-client.jks -alias selfsigned -certreq -file $OUTPUT/client.unsigned -storepass secret
  openssl x509 -extfile $OUTPUT/openssl.cnf -extensions extended -req -CA $OUTPUT/ca-cert -CAkey $OUTPUT/ca-key -in $OUTPUT/client.unsigned -out $OUTPUT/client.signed -days 365 -CAcreateserial -passin pass:secret

  ## Sign server certificate
  keytool -noprompt -keystore $OUTPUT/keystore-server.jks -alias selfsigned -certreq -file $OUTPUT/server.unsigned -storepass secret
  openssl x509 -extfile $OUTPUT/openssl.cnf -extensions extended -req -CA $OUTPUT/ca-cert -CAkey $OUTPUT/ca-key -in $OUTPUT/server.unsigned -out $OUTPUT/server.signed -days 365 -CAcreateserial -passin pass:secret

  ## Sign filebeat certificate
  keytool -noprompt -keystore $OUTPUT/keystore-filebeat.jks -alias selfsigned -certreq -file $OUTPUT/filebeat.unsigned -storepass secret
  openssl x509 -extfile $OUTPUT/openssl.cnf -extensions extended -req -CA $OUTPUT/ca-cert -CAkey $OUTPUT/ca-key -in $OUTPUT/filebeat.unsigned -out $OUTPUT/filebeat.signed -days 365 -CAcreateserial -passin pass:secret

  ## Sign kibana certificate
  keytool -noprompt -keystore $OUTPUT/keystore-kibana.jks -alias selfsigned -certreq -file $OUTPUT/kibana.unsigned -storepass secret
  openssl x509 -extfile $OUTPUT/openssl.cnf -extensions extended -req -CA $OUTPUT/ca-cert -CAkey $OUTPUT/ca-key -in $OUTPUT/kibana.unsigned -out $OUTPUT/kibana.signed -days 365 -CAcreateserial -passin pass:secret

  ## Sign logstash certificate
  keytool -noprompt -keystore $OUTPUT/keystore-logstash.jks -alias selfsigned -certreq -file $OUTPUT/logstash.unsigned -storepass secret
  openssl x509 -extfile $OUTPUT/openssl.cnf -extensions extended -req -CA $OUTPUT/ca-cert -CAkey $OUTPUT/ca-key -in $OUTPUT/logstash.unsigned -out $OUTPUT/logstash.signed -days 365 -CAcreateserial -passin pass:secret

  ## Sign elasticsearch certificate
  keytool -noprompt -keystore $OUTPUT/keystore-elasticsearch.jks -alias selfsigned -certreq -file $OUTPUT/elasticsearch.unsigned -storepass secret
  openssl x509 -extfile $OUTPUT/openssl.cnf -extensions extended -req -CA $OUTPUT/ca-cert -CAkey $OUTPUT/ca-key -in $OUTPUT/elasticsearch.unsigned -out $OUTPUT/elasticsearch.signed -days 365 -CAcreateserial -passin pass:secret

  ## Sign consul certificate
  keytool -noprompt -keystore $OUTPUT/keystore-consul.jks -alias selfsigned -certreq -file $OUTPUT/consul.unsigned -storepass secret
  openssl x509 -extfile $OUTPUT/openssl.cnf -extensions extended -req -CA $OUTPUT/ca-cert -CAkey $OUTPUT/ca-key -in $OUTPUT/consul.unsigned -out $OUTPUT/consul.signed -days 365 -CAcreateserial -passin pass:secret

  ## Import CA and client signed certificate into client keystore
  keytool -noprompt -keystore $OUTPUT/keystore-client.jks -alias CARoot -import -file $OUTPUT/ca-cert  -storepass secret
  keytool -noprompt -keystore $OUTPUT/keystore-client.jks -alias selfsigned -import -file $OUTPUT/client.signed -storepass secret

  ## Import CA and server signed certificate into server keystore
  keytool -noprompt -keystore $OUTPUT/keystore-server.jks -alias CARoot -import -file $OUTPUT/ca-cert  -storepass secret
  keytool -noprompt -keystore $OUTPUT/keystore-server.jks -alias selfsigned -import -file $OUTPUT/server.signed -storepass secret

  ## Import CA and filebeat signed certificate into filebeat keystore
  keytool -noprompt -keystore $OUTPUT/keystore-filebeat.jks -alias CARoot -import -file $OUTPUT/ca-cert  -storepass secret
  keytool -noprompt -keystore $OUTPUT/keystore-filebeat.jks -alias selfsigned -import -file $OUTPUT/filebeat.signed -storepass secret

  ## Import CA and kibana signed certificate into kibana keystore
  keytool -noprompt -keystore $OUTPUT/keystore-kibana.jks -alias CARoot -import -file $OUTPUT/ca-cert  -storepass secret
  keytool -noprompt -keystore $OUTPUT/keystore-kibana.jks -alias selfsigned -import -file $OUTPUT/kibana.signed -storepass secret

  ## Import CA and logstash signed certificate into logstash keystore
  keytool -noprompt -keystore $OUTPUT/keystore-logstash.jks -alias CARoot -import -file $OUTPUT/ca-cert  -storepass secret
  keytool -noprompt -keystore $OUTPUT/keystore-logstash.jks -alias selfsigned -import -file $OUTPUT/logstash.signed -storepass secret

  ## Import CA and elasticsearch signed certificate into elasticsearch keystore
  keytool -noprompt -keystore $OUTPUT/keystore-elasticsearch.jks -alias CARoot -import -file $OUTPUT/ca-cert  -storepass secret
  keytool -noprompt -keystore $OUTPUT/keystore-elasticsearch.jks -alias selfsigned -import -file $OUTPUT/elasticsearch.signed -storepass secret

  ## Import CA and consul signed certificate into consul keystore
  keytool -noprompt -keystore $OUTPUT/keystore-consul.jks -alias CARoot -import -file $OUTPUT/ca-cert  -storepass secret
  keytool -noprompt -keystore $OUTPUT/keystore-consul.jks -alias selfsigned -import -file $OUTPUT/consul.signed -storepass secret

  ## Import CA into client truststore
  keytool -noprompt -keystore $OUTPUT/truststore-client.jks -alias CARoot -import -file $OUTPUT/ca-cert -storepass secret

  ## Import CA into server truststore
  keytool -noprompt -keystore $OUTPUT/truststore-server.jks -alias CARoot -import -file $OUTPUT/ca-cert -storepass secret

  ## Create PEM files for NGINX, Logstash, Filebeat, Elasticsearch, Consul

  ### Extract signed client certificate
  keytool -noprompt -keystore $OUTPUT/keystore-client.jks -exportcert -alias selfsigned -rfc -storepass secret -file $OUTPUT/client_cert.pem

  ### Extract client key
  keytool -noprompt -srckeystore $OUTPUT/keystore-client.jks -importkeystore -srcalias selfsigned -destkeystore $OUTPUT/client_cert_and_key.p12 -deststoretype PKCS12 -srcstorepass secret -storepass secret
  openssl pkcs12 -in $OUTPUT/client_cert_and_key.p12 -nocerts -nodes -passin pass:secret -out $OUTPUT/client_key.pem

  ### Extract signed server certificate
  keytool -noprompt -keystore $OUTPUT/keystore-server.jks -exportcert -alias selfsigned -rfc -storepass secret -file $OUTPUT/server_cert.pem

  ### Extract server key
  keytool -noprompt -srckeystore $OUTPUT/keystore-server.jks -importkeystore -srcalias selfsigned -destkeystore $OUTPUT/server_cert_and_key.p12 -deststoretype PKCS12 -srcstorepass secret -storepass secret
  openssl pkcs12 -in $OUTPUT/server_cert_and_key.p12 -nocerts -nodes -passin pass:secret -out $OUTPUT/server_key.pem

  ### Extract signed filebeat certificate
  keytool -noprompt -keystore $OUTPUT/keystore-filebeat.jks -exportcert -alias selfsigned -rfc -storepass secret -file $OUTPUT/filebeat_cert.pem

  ### Extract filebeat key
  keytool -noprompt -srckeystore $OUTPUT/keystore-filebeat.jks -importkeystore -srcalias selfsigned -destkeystore $OUTPUT/filebeat_cert_and_key.p12 -deststoretype PKCS12 -srcstorepass secret -storepass secret
  openssl pkcs12 -in $OUTPUT/filebeat_cert_and_key.p12 -nocerts -nodes -passin pass:secret -out $OUTPUT/filebeat_key.pem

  ### Extract signed kibana certificate
  keytool -noprompt -keystore $OUTPUT/keystore-kibana.jks -exportcert -alias selfsigned -rfc -storepass secret -file $OUTPUT/kibana_cert.pem

  ### Extract kibana key
  keytool -noprompt -srckeystore $OUTPUT/keystore-kibana.jks -importkeystore -srcalias selfsigned -destkeystore $OUTPUT/kibana_cert_and_key.p12 -deststoretype PKCS12 -srcstorepass secret -storepass secret
  openssl pkcs12 -in $OUTPUT/kibana_cert_and_key.p12 -nocerts -nodes -passin pass:secret -out $OUTPUT/kibana_key.pem

  ### Extract signed logstash certificate
  keytool -noprompt -keystore $OUTPUT/keystore-logstash.jks -exportcert -alias selfsigned -rfc -storepass secret -file $OUTPUT/logstash_cert.pem

  ### Extract logstash key
  keytool -noprompt -srckeystore $OUTPUT/keystore-logstash.jks -importkeystore -srcalias selfsigned -destkeystore $OUTPUT/logstash_cert_and_key.p12 -deststoretype PKCS12 -srcstorepass secret -storepass secret
  openssl pkcs12 -in $OUTPUT/logstash_cert_and_key.p12 -nocerts -nodes -passin pass:secret -out $OUTPUT/logstash_key.pem

  ### Extract signed elasticsearch certificate
  keytool -noprompt -keystore $OUTPUT/keystore-elasticsearch.jks -exportcert -alias selfsigned -rfc -storepass secret -file $OUTPUT/elasticsearch_cert.pem

  ### Extract elasticsearch key
  keytool -noprompt -srckeystore $OUTPUT/keystore-elasticsearch.jks -importkeystore -srcalias selfsigned -destkeystore $OUTPUT/elasticsearch_cert_and_key.p12 -deststoretype PKCS12 -srcstorepass secret -storepass secret
  openssl pkcs12 -in $OUTPUT/elasticsearch_cert_and_key.p12 -nocerts -nodes -passin pass:secret -out $OUTPUT/elasticsearch_key.pem

  ### Extract signed consul certificate
  keytool -noprompt -keystore $OUTPUT/keystore-consul.jks -exportcert -alias selfsigned -rfc -storepass secret -file $OUTPUT/consul_cert.pem

  ### Extract consul key
  keytool -noprompt -srckeystore $OUTPUT/keystore-consul.jks -importkeystore -srcalias selfsigned -destkeystore $OUTPUT/consul_cert_and_key.p12 -deststoretype PKCS12 -srcstorepass secret -storepass secret
  openssl pkcs12 -in $OUTPUT/consul_cert_and_key.p12 -nocerts -nodes -passin pass:secret -out $OUTPUT/consul_key.pem

  ### Extract CA certificate
  keytool -noprompt -keystore $OUTPUT/keystore-server.jks -exportcert -alias CARoot -rfc -storepass secret -file $OUTPUT/ca_cert.pem

  ### Copy keystores and truststores

  cat $OUTPUT/client_cert.pem $OUTPUT/ca_cert.pem > $OUTPUT/ca_and_client_cert.pem
  cat $OUTPUT/server_cert.pem $OUTPUT/ca_cert.pem > $OUTPUT/ca_and_server_cert.pem

  openssl pkcs8 -in $OUTPUT/filebeat_key.pem -topk8 -inform PEM -nocrypt -out $OUTPUT/filebeat_key.pkcs8
  openssl pkcs8 -in $OUTPUT/kibana_key.pem -topk8 -inform PEM -nocrypt -out $OUTPUT/kibana_key.pkcs8
  openssl pkcs8 -in $OUTPUT/logstash_key.pem -topk8 -inform PEM -nocrypt -out $OUTPUT/logstash_key.pkcs8
  openssl pkcs8 -in $OUTPUT/elasticsearch_key.pem -topk8 -inform PEM -nocrypt -out $OUTPUT/elasticsearch_key.pkcs8

  openssl x509 -noout -text -in $OUTPUT/consul_cert.pem
  openssl x509 -noout -text -in $OUTPUT/filebeat_cert.pem
  openssl x509 -noout -text -in $OUTPUT/kibana_cert.pem
  openssl x509 -noout -text -in $OUTPUT/logstash_cert.pem
  openssl x509 -noout -text -in $OUTPUT/elasticsearch_cert.pem

else

  echo "Secrets folder already exists. Skipping!"

fi
