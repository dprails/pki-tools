#!/usr/bin/env bash

set -e

# use truststore password for all prompts

# convert truststore.jks into truststore.p12
keytool -importkeystore -srckeystore truststore.jks -destkeystore truststore.p12 -srcstoretype jks -deststoretype pkcs12

# convert truststore.p12 into truststore.pem
openssl pkcs12 -in truststore.p12 -out truststore.pem
