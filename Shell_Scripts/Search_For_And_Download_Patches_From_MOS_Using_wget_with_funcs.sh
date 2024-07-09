#!/bin/bash
## Variables
COOKIE_FILE=$(mktemp -t wget_sh_XXXXXX)
# WGET="/usr/bin/wget"
OUTPUT_DIR=.
prog_name=${0##*/}
flag_name=$1
export PATCH_NUMBER=$2

## FUNCTION TO PRINT USAGE
function usage() {
  printf "\nCORRECT USAGE:\n\n${prog_name} -p <patch_number>\n\nOR\n\n${prog_name} --patch <patch_number>\n\n"

}

## Function to ensure that wget is installed and available in the PATH variable. Else, exit.
function check_wget_available() {
  wget_installed_flag=$(which wget > /dev/null 2>&1; echo $?)
  if [[ ${wget_installed_flag} -eq 0 ]]; then
    export WGET=$(which wget)
    printf "The executable 'wget' is indeed available in the PATH variable. Proceeding further.....\n\n"
  else
    printf "The 'wget' executable isn't available in the 'PATH' variable. Can't proceed without it. Exiting......\n\n\n"
    exit 2
  fi
}

## FUNCTION TO CHECK IF THE GIVEN VARIABLE IS A NUMBER.
function isint(){
  case $1 in
      ''|*[!0-9]*) echo NON_INT ;;
      *) echo INT ;;
  esac

}

## FUNCTION TO VALIDATE ARGUMENTS
function validate_args() {
  ## Validate the first argument - It should be "-p" or "--patch"
  if [[ "${flag_name}" != "-p" && "${flag_name}" != "--patch" ]]; then
    printf "\n Invalid named parameter passed - '${flag_name}'\n"
    usage
    printf "\n\nExiting.....\n\n"
    exit 2
  else
    printf "The passed named parameter name - '${flag_name}' - is indeed correct. Proceeding to check the validity of the passed patch number....\n\n"
  fi

  ## Validate the second argument - i.e., patch_number
  ## Ensure that the passed argument is a numeral.
  CHECK_IF_INT=$(isint ${PATCH_NUMBER})
  if [[ "${CHECK_IF_INT}" == "INT" ]]; then
    printf "The passed patch number - '${PATCH_NUMBER}' - is indeed an integer. Proceeding further....\n\n"
  else
    printf "The passed patch number - '${PATCH_NUMBER}' - is NOT AN INTEGER. Pass only a numeral. Can't proceed further. Exiting.....\n\n"
    exit 2
  fi

}

###### MAIN ######
## Ensure that 2 arguments are passed. Else, exit.
if [[ $# -ne 2 ]]; then
  printf "\nInvalid arguments passed\n\n"
  usage
  printf "\n\nExiting.....\n\n"
  exit 2
fi

## Call the function to validate the arguments and check if wget is available in the PATH variable.
validate_args
check_wget_available

## Ask MOS username and password and store them in the wgetrc file.
read -p "Enter your MOS Username: " mos_login_user_name
read -s -p "Enter you password: " mos_login_password

## Now, create the wgetrc file using the above two values.
printf "http_user = ${mos_login_user_name}\nhttp_password = ${mos_login_password}\n" > ${WGETRC}
export WGETRC="${OUTPUT_DIR}/wgetrc"

## Change permissions of the WGETRC file so that only the owner is able to read and write to the file.
chmod 600 ${WGETRC}

## Now, execute wget and save the output to the cookie file.
${WGET}  --secure-protocol=auto --save-cookies="${COOKIE_FILE}" --keep-session-cookies "https://updates.oracle.com/Orion/Services/download" -O /dev/null

## Use the cookie file to login and then search for the mentioned patch using wget and store the wget output in a file - wget_patch_search_output.txt
export PATCH_SEARCH_FILE="${OUTPUT_DIR}/wget_patch_search_output.txt"
${WGET}  --load-cookies="${COOKIE_FILE}" --keep-session-cookies "https://updates.oracle.com/Orion/SimpleSearch/process_form?search_type=patch&patch_number=${PATCH_NUMBER}&plat_lang=226P" -O "${PATCH_SEARCH_FILE}"
## Explanation of the above command:
## --load-cookies --> The cookies will be loaded from the  cookie file saved from the previous step

## Ensure that the patch indeed exists. If it doesn't exist, then exit the script since the patch number is incorrect.
PATCH_NOT_FOUND_COUNT=$(grep "No patches found" ${PATCH_SEARCH_FILE} | wc -l)
if [[ ${PATCH_NOT_FOUND_COUNT} -ne 0 ]]; then
  printf "The Patch entered - '${PATCH_NUMBER}' doesn't exist. Provide the correct patch number. Exiting.....\n\n\n"
  exit 2
else
  printf "The Patch entered - '${PATCH_NUMBER}' indeed exists. Proceeding to fetch the download URL.....\n\n"
fi

## From the output file, search only for the patch that need and deduce the patch download url
PATCH_DOWNLOAD_URL=$(grep ".*${PATCH_NUMBER}.*zip" ${PATCH_SEARCH_FILE} | sed -e 's,^.*\href[^"]*",,g; s,".*$,,g')

## Now, deduce the patch file name.
PATCH_FILE_NAME=$(grep ".*${PATCH_NUMBER}.*zip" wget_patch_search_output.txt | sed -e 's,^.*\href[^"]*",,g; s,".*$,,g; s,^.*patch_file=,,g')
PATCH_FILE_FULL_PATH="${OUTPUT_DIR}/${PATCH_FILE_NAME}"

## Now, download the patch using wget as below.
${WGET}  --load-cookies="${COOKIE_FILE}" --keep-session-cookies "${PATCH_DOWNLOAD_URL}" -O "${PATCH_FILE_FULL_PATH}"

## Also, fetch the patch XML in order to make sure that sha-256sum matches.
export PATCH_XML="${OUTPUT_DIR}/patch_${PATCH_NUMBER}.xml"
${WGET}  --load-cookies="${COOKIE_FILE}" --keep-session-cookies "https://updates.oracle.com/Orion/Services/search?bug=${PATCH_NUMBER}" -O "${PATCH_XML}"

## Extract the md5 checksum for the patch from the downloaded xml.
PATCH_SHA256SUM_FROM_XML=$(awk '/SHA-256/' ${PATCH_XML} | sed -e 's,.*">\(.*\)</.*,\1,')

## Find the sha-256 checksum for the downloaded file.
PATCH_SHA256SUM_FROM_FILE=$(sha256sum ${OUTPUT_DIR}/${PATCH_FILE_NAME} | awk '{print $1}' | tr '[a-z]' '[A-Z]')

## Check if both the sums match. If they don't, then delete the patch. If they do, then the patch is valid.
if [[ "${PATCH_SHA256SUM_FROM_XML}" == "${PATCH_SHA256SUM_FROM_FILE}" ]]; then
  printf "\nSHA256sum of downloaded patch\t\t:\t${PATCH_SHA256SUM_FROM_FILE}\nSHA256sum of patch as per the XML \t:\t${PATCH_SHA256SUM_FROM_XML}\n\nBoth of them match. So, patch is valid and good to apply.\n\n"
else
  printf "\nSHA256sum of downloaded patch\t\t:\t${PATCH_SHA256SUM_FROM_FILE}\nSHA256sum of patch as per the XML \t\t:\t${PATCH_SHA256SUM_FROM_XML}\n\nBoth of them DO NOT MATCH. So, the downloaded patch is not valid. Deleting the same.......\n\n"
  rm -f ${PATCH_FILE_FULL_PATH}
fi
