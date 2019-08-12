#!/usr/bin/env bash

set -e

### assumes openssl is installed, that we are running on linux variant, and example-pki-scripts have been installed local
### to current directory

echo "creating pki directory"
mkdir -p pki/admin
cd example-pki-scripts
ca_password="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)"
echo $ca_password > ../pki/ca_password.txt
truststore_password="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)"
echo $truststore_password > ../pki/truststore_password.txt
echo "generating root CA..."
./gen_root_ca.sh $ca_password $truststore_password
cp ca/root-ca.pem ../pki/.
mv truststore.jks ../pki/.

echo "Enter FQDN of node (example: zookeeper.dprails.com):"
read node_name
node_dn=$node_name
echo "Enter Organization Name:"
read org_name
echo "Creating pki keys for $node_dn..."
node_password="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)"
./gen_node_cert_openssl.sh "/$node_dn/OU=IT/O=$org_name/L=San Francisco/C=US" "$node_dn" "$node_dn" $node_password $ca_password
mkdir -p ../pki/$node_dn
node_password_file=$node_dn"_password.txt"
echo "saving password to $node_password_file"
echo $node_password > ../pki/node_keystore_password.txt
mv $node_dn* ../pki/$node_dn/.
cp ../pki/$node_dn/$node_dn.crt.pem ../pki/node.pem
cp ../pki/$node_dn/$node_dn.key ../pki/node.key

echo "generating admin certificate"
admin_password="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)"
echo $admin_password > ../pki/admin_password.txt
export set DN="CN=admin,OU=IT,O=$org_name,L=San Francisco,C=US"
./gen_client_node_cert.sh admin $admin_password $ca_password
mv admin* ../pki/admin/.
cp ../pki/admin/admin-keystore.jks ../pki/admin-keystore.jks

#echo "pki keys generated and stored in pki directory, uploading these to S3 for safe keeping. Enter the s3 bucket and path to upload to:"
#cd ../
#read s3_bucket_path
#echo "uploading pki keys to s3://$s3_bucket_path/pki..."
#aws s3 cp pki/ s3://$s3_bucket_path/ --recursive
#echo "uploading root ca to s3://$s3_bucket_path/pki/ca..."
#aws s3 cp search-guard-ssl/example-pki-scripts/ca/ s3://$s3_bucket_path/ca/ --recursive
