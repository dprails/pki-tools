FROM ubuntu:18.04

ARG OPENSSL_VERSION=1.1.1c

# Let's start with some basic stuff.
RUN apt-get update -qq && apt-get install -qqy \
    apt-transport-https \
    ca-certificates \
    curl \
    build-essential \
    lxc \
    iptables \
    default-jre \
    git \
    net-tools \
    unzip \
    python \
&& rm -rf /var/lib/apt/lists/*

# install openssl
RUN curl --silent https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz -o /tmp/openssl-${OPENSSL_VERSION}.tgz && \
  cd /tmp && tar -xzf openssl-${OPENSSL_VERSION}.tgz && \
  cd openssl-${OPENSSL_VERSION} && ./config && make depend && make install && make uninstall_docs && \
  ln -sf /usr/local/ssl/bin/openssl `which openssl` && \
  cd / && \
  rm -rf /tmp/openssl-${OPENSSL_VERSION}

# Install aws cli
RUN curl --silent https://s3.amazonaws.com/aws-cli/awscli-bundle.zip -o awscli-bundle.zip && \
    /usr/bin/unzip awscli-bundle.zip && \
    cd awscli-bundle && \
    ./install -i /usr/local/aws -b /usr/local/bin/aws

RUN mkdir -p /pki-tools

# Install searchguard example-pki-scripts
RUN curl --silent  https://dprails-utils.s3-us-west-2.amazonaws.com/example-pki-scripts.tgz -o /pki-tools/example-pki-scripts.tgz && \
  cd /pki-tools && \
  tar -xzf example-pki-scripts.tgz && \
  rm -f example-pki-scripts.tgz

WORKDIR /pki-tools
COPY create_pki_keys.sh /pki-tools/.

CMD ["/bin/bash","-l"]
