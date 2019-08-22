#!/usr/bin/env bash

set -e

KEYSTORE_FILENAME="keystore.jks"
VALIDITY_IN_DAYS=3650
DEFAULT_TRUSTSTORE_FILENAME="truststore.jks"
TRUSTSTORE_WORKING_DIRECTORY="pki/truststore"
KEYSTORE_WORKING_DIRECTORY="pki/keystore"
CA_CERT_FILE="ca-cert"
KEYSTORE_SIGN_REQUEST="cert-file"
KEYSTORE_SIGN_REQUEST_SRL="ca-cert.srl"
KEYSTORE_SIGNED_CERT="cert-signed"

function file_exists_and_exit() {
  echo "'$1' cannot exist. Move or delete it before"
  echo "re-running this script."
  exit 1
}

if [ -e "$KEYSTORE_WORKING_DIRECTORY" ]; then
  file_exists_and_exit $KEYSTORE_WORKING_DIRECTORY
fi

if [ -e "$CA_CERT_FILE" ]; then
  file_exists_and_exit $CA_CERT_FILE
fi

if [ -e "$KEYSTORE_SIGN_REQUEST" ]; then
  file_exists_and_exit $KEYSTORE_SIGN_REQUEST
fi

if [ -e "$KEYSTORE_SIGN_REQUEST_SRL" ]; then
  file_exists_and_exit $KEYSTORE_SIGN_REQUEST_SRL
fi

if [ -e "$KEYSTORE_SIGNED_CERT" ]; then
  file_exists_and_exit $KEYSTORE_SIGNED_CERT
fi

echo
echo "Welcome to the Kafka SSL keystore and truststore generator script."
echo

trust_store_file=""
trust_store_private_key_file=""

if [ -e "$TRUSTSTORE_WORKING_DIRECTORY" ]; then
  file_exists_and_exit $TRUSTSTORE_WORKING_DIRECTORY
fi

mkdir -p $TRUSTSTORE_WORKING_DIRECTORY
echo
echo "OK, we'll generate a trust store and associated private key, certificate"
echo
echo "You will be prompted for:"
echo " - Information about you and your company."
echo " - NOTE that the Common Name (CN) is currently not important."
echo
echo "Enter Common Name(CN) (example: dprails.com):"
read node_name
node_dn=$node_name
echo "Enter Organization Name:"
read org_name
echo "Enter Organization Unit:"
read org_unit
echo "Enter City or Locality:"
read city
echo "Enter State or Province:"
read state
echo "Enter two-letter country code:"
read country
subject="/CN=$node_name/OU=$org_unit/O=$org_name/L=$city/ST=$state/C=$country"

echo "autogenerating ca password and storing in $TRUSTSTORE_WORKING_DIRECTORY/ca_password.txt"
ca_password="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)"
echo $ca_password > $TRUSTSTORE_WORKING_DIRECTORY/ca_password.txt

openssl req -new -x509 -keyout $TRUSTSTORE_WORKING_DIRECTORY/ca-key \
  -out $TRUSTSTORE_WORKING_DIRECTORY/ca-cert -days $VALIDITY_IN_DAYS \
  -subj "$subject" -passout "pass:$ca_password"

trust_store_private_key_file="$TRUSTSTORE_WORKING_DIRECTORY/ca-key"

#echo "Two files were created:"
#echo " - $TRUSTSTORE_WORKING_DIRECTORY/ca-key -- the private key used later to"
#echo "   sign certificates"
#echo " - $TRUSTSTORE_WORKING_DIRECTORY/ca-cert -- the certificate that will be"
#echo "   stored in the trust store in a moment and serve as the certificate"
#echo "   authority (CA). Once this certificate has been stored in the trust"
#echo "   store, it will be deleted. It can be retrieved from the trust store via:"
#echo "   $ keytool -keystore <trust-store-file> -export -alias CARoot -rfc"

echo "Now the trust store will be generated from the certificate..."
echo
echo "autogenerating truststore password and storing in $TRUSTSTORE_WORKING_DIRECTORY/truststore_password.txt"
truststore_password="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)"
echo $truststore_password > $TRUSTSTORE_WORKING_DIRECTORY/truststore_password.txt

keytool -import -file $TRUSTSTORE_WORKING_DIRECTORY/ca-cert -noprompt \
  -alias CARoot -keystore $TRUSTSTORE_WORKING_DIRECTORY/$DEFAULT_TRUSTSTORE_FILENAME -storepass $truststore_password

trust_store_file="$TRUSTSTORE_WORKING_DIRECTORY/$DEFAULT_TRUSTSTORE_FILENAME"

base64 $trust_store_file > $TRUSTSTORE_WORKING_DIRECTORY/$DEFAULT_TRUSTSTORE_FILENAME.base64

echo
echo "$trust_store_file and $trust_store_file.base64 was created."

# don't need the cert because it's in the trust store.
rm $TRUSTSTORE_WORKING_DIRECTORY/$CA_CERT_FILE

echo
echo "Now, a keystore will be generated. Each broker and logical client needs its own"
echo "keystore. This script will create a keystore for each node fqdn."

echo "Enter number of nodes:"
read node_num

counter=1
limit=$((1+node_num))
while [ $counter -lt $limit ]; do

  echo "Enter Node FQDN (example: zk1.dprails.com):"
  read node_fqdn

  KEYSTORE_DIR=pki/$node_fqdn
  mkdir $KEYSTORE_DIR

  # To learn more about CNs and FQDNs, read:
  # https://docs.oracle.com/javase/7/docs/api/javax/net/ssl/X509ExtendedTrustManager.html

  echo "autogenerating keystore password and storing in $KEYSTORE_DIR/keystore_password.txt"
  keystore_password="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)"
  echo $keystore_password > $KEYSTORE_DIR/keystore_password.txt

  dname="CN=$node_fqdn, ou=$org_unit, o=$org_name, L=$city, S=$state, C=$country"

  keytool -genkeypair -keystore $KEYSTORE_DIR/$KEYSTORE_FILENAME \
    -alias localhost -validity $VALIDITY_IN_DAYS -keyalg RSA \
    -dname "$dname" -storepass $keystore_password -keypass $keystore_password

  echo "$KEYSTORE_DIR/$KEYSTORE_FILENAME now contains a key pair and a self-signed certificate."

  echo
  echo "Fetching the certificate from the trust store and storing in $CA_CERT_FILE."
  echo

  keytool -export -keystore $trust_store_file -alias CARoot -rfc -file $CA_CERT_FILE -storepass $truststore_password

  echo
  echo "Now a certificate signing request will be made to the keystore."
  keytool -certreq -keystore $KEYSTORE_DIR/$KEYSTORE_FILENAME -alias localhost \
     -file $KEYSTORE_SIGN_REQUEST -storepass $keystore_password

  echo
  echo "Now the trust store's private key (CA) will sign the keystore's certificate."
  openssl x509 -req -CA $CA_CERT_FILE -CAkey $trust_store_private_key_file \
    -in $KEYSTORE_SIGN_REQUEST -out $KEYSTORE_SIGNED_CERT \
    -days $VALIDITY_IN_DAYS -CAcreateserial -passin "pass:$ca_password"
  # creates $KEYSTORE_SIGN_REQUEST_SRL which is never used or needed.

  echo
  echo "Now the CA will be imported into the keystore."
  echo
  keytool -import -keystore $KEYSTORE_DIR/$KEYSTORE_FILENAME -alias CARoot \
    -file $CA_CERT_FILE -storepass $keystore_password -noprompt
  rm $CA_CERT_FILE # delete the trust store cert because it's stored in the trust store.

  echo
  echo "Now the keystore's signed certificate will be imported back into the keystore."
  keytool -import -keystore $KEYSTORE_DIR/$KEYSTORE_FILENAME -alias localhost \
    -file $KEYSTORE_SIGNED_CERT -storepass $keystore_password

  echo
  echo "creating base64 of keystore"
  base64 $KEYSTORE_DIR/$KEYSTORE_FILENAME > $KEYSTORE_DIR/$KEYSTORE_FILENAME.base64

  echo
  echo "All done! Deleting intermediate files"
  rm $KEYSTORE_SIGN_REQUEST_SRL
  rm $KEYSTORE_SIGN_REQUEST
  rm $KEYSTORE_SIGNED_CERT
  let counter=counter+1
done
