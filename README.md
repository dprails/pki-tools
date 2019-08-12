# pki-tools
Docker image containing handy script for creating TLS keys. These keys should be used for development purposes only


# Creating TLS keys
1. shell into container
`$ docker run -it -v $(pwd):/pki-tools/pki dprails/pki-tools /bin/bash`
2. run script
`# ./create_pki_keys.sh`
3. keys created in  your host's $(pwd)/pki directory
