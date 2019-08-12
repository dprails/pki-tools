# pki-tools
Docker image containing handy script for creating TLS keys. These keys should be used for development purposes only


# Creating TLS keys
1. shell into container
`$ docker run -it dprails/pki-tools /bin/bash`
2. run script
`# ./create_pki_keys.sh`
3. keys created in pki directory
4. copy keys out of container to use as needed
