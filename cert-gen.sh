#!/bin/bash
set -e
set -u

# includes
source includes.sh

# usage check
if [ $# -ne 1 ]; then
	echo "usage: $0 <FQDN>"
	exit 1
fi

HOST=$1
HOST_CERTS="${HOST}_certificates"
SUBJ="/C=CH/ST=Bern/L=Bern/O=jamesclonk.io/OU=webdev/CN=${HOST}"
PASSWORD=$(openssl rand -base64 32)

rm -rf ${HOST_CERTS} || true
mkdir ${HOST_CERTS}
cd ${HOST_CERTS}
trap "cd ..; exit" INT TERM EXIT

# generate certificates
header "${HOST}: Create server keys"
openssl genrsa -passout pass:${PASSWORD} -aes256 -out ca-key.pem 2048
openssl req -passin pass:${PASSWORD} -new -x509 -days 3650 -key ca-key.pem -sha256 -out ca.pem -subj ${SUBJ}
openssl genrsa -out server-key.pem 2048
openssl req -new -key server-key.pem -out server.csr -subj ${SUBJ} 
openssl x509 -passin pass:${PASSWORD} -req -days 3650 -in server.csr -CA ca.pem -CAkey ca-key.pem \
    -CAcreateserial -out server-cert.pem

header "${HOST}: Create client keys"
openssl genrsa -out key.pem 2048
openssl req -subj '/CN=client' -new -key key.pem -out client.csr
echo "extendedKeyUsage = clientAuth" > extfile.cnf
openssl x509 -passin pass:${PASSWORD} -req -days 3650 -in client.csr -CA ca.pem -CAkey ca-key.pem \
    -CAcreateserial -out cert.pem -extfile extfile.cnf

header "${HOST}: Strip password from keys"
openssl rsa -in server-key.pem -out server-key.pem
openssl rsa -in key.pem -out key.pem

header "${HOST}: Remove files"
rm -vf client.csr server.csr
rm -vf extfile.cnf
rm -vf ca.srl

header "${HOST}: Chmod keys"
chmod -v 400 ca-key.pem key.pem server-key.pem
chmod -v 440 ca.pem server-cert.pem cert.pem
chmod -v 750 .

header "${HOST}: Certificates generated"
ls -l

cd ..

exit 0
