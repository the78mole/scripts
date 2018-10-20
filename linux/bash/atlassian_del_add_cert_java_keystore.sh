#!/bin/bash

function show_usage() {
				echo -e "\n\nUsage: $0 <DOMAIN>|-h"
				echo -e "\n   DOMAIN: The alias/domainname of your certificate"
				echo -e "       -h: Show this usage help\n\n"
}

if [ "x$1" == "x" ]; then
				echo "Please provide an alias/domain to get the certificate from. Aborting"
				show_usage
				exit 1
fi

if [ "$1" == "-h" ]; then
				show_usage
				exit 0
fi

ATL_PATH=/opt/atlassian
KEYSTORE_PASS=changeit
CERT_ALIAS=$1
CERT_URL=$1:443
CERT_FILE=${CERT_ALIAS}.crt

if [ -f "${CERT_FILE}" ]; then
	echo "Certificate already exists. Aborting."
	exit 1
fi

echo "Downloading the certificate ${CERT_ALIAS} from ${CERT_URL}."
sleep 1
openssl s_client -showcerts -servername ${CERT_ALIAS} -connect ${CERT_URL} </dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > ${CERT_FILE}

# Now process the tools' keystore
for tool in jira confluence bitbucket; do

	case ${tool} in
		bitbucket)
			TOOL_PATH=$(find ${ATL_PATH}/${tool} -maxdepth 1 -type d | tail -n 1)
			if [[ $? -ne 0 ]]; then
				echo "Error evaluating bitbucket path. Abort!"
				exit 1
			fi
			;;
		*)
			TOOL_PATH=${ATL_PATH}/${tool}
			;;
	esac
	JRE_PATH=${TOOL_PATH}/jre

	echo -e "\n\nProcessing tool : $tool"
	echo "    Cert alias  : ${CERT_ALIAS}"
	echo "    Tool path   : ${TOOL_PATH}"
	echo "    JRA  path   : ${JRE_PATH}"
	ALIAS_CHECK_TEXT=$(${JRE_PATH}/bin/keytool -list -alias ${CERT_ALIAS} -storepass ${KEYSTORE_PASS} -keystore ${JRE_PATH}/lib/security/cacerts 2>&1)
	HAS_ALIAS=$?
	echo "    Alias check : ${ALIAS_CHECK_TEXT/$'\n'/}"
	if [[ ${HAS_ALIAS} -eq 0 ]]; then
		echo "    Action      : Deleting alias entry... (Returned ${HAS_ALIAS})"
		${JRE_PATH}/bin/keytool -delete -alias ${CERT_ALIAS} \
			-storepass ${KEYSTORE_PASS} \
			-keystore ${JRE_PATH}/lib/security/cacerts
	fi
	echo "    Importing   : ${CERT_FILE}"
	IMPORT_TEXT=$(${JRE_PATH}/bin/keytool -import -alias ${CERT_ALIAS} \
		-storepass ${KEYSTORE_PASS} -noprompt \
		-keystore ${JRE_PATH}/lib/security/cacerts \
		-file ${CERT_FILE} 2>&1)
	HAS_IMPORT=$?
	echo "    Import out  : ${IMPORT_TEXT/$'\n'/} (${HAS_IMPORT})"
done

exit 0
