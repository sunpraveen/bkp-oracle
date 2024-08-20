#!/bin/bash
# *==================================================================================+
# |
# | FILENAME    : fetch_languages_and_platforms_in_patch_search.sh
# | DESCRIPTION : Fetch all the languages and platforms that are available in MOS - patch search
# | USAGE       : fetch_languages_and_platforms_in_patch_search.sh
# | AUTHOR      : Praveen B K
# |
# +==================================================================================+
## Variables
COOKIE_FILE=$(mktemp -t wget_sh_XXXXXX)
# WGET=/usr/bin/wget
OUTPUT_DIR=.
TMP1="/tmp/patch_lang.txt"

## Ensure that wget is installed and available in the PATH variable. Else, exit.
wget_installed_flag=$(which wget > /dev/null 2>&1; echo $?)
if [[ ${wget_installed_flag} -eq 0 ]]; then
  export WGET=$(which wget)
  printf "The executable 'wget' is indeed available in the PATH variable. Proceeding further.....\n\n"
else
  printf "The 'wget' executable isn't available in the 'PATH' variable. Can't proceed without it. Exiting......\n\n\n"
  exit 2
fi

## Ask MOS username and password and store them in the wgetrc file.
read -p "Enter your MOS Username: " mos_login_user_name
read -s -p "Enter you password: " mos_login_password

## Now, create the wgetrc file using the above two values.
printf "http_user = ${mos_login_user_name}\nhttp_password = ${mos_login_password}\n" > ${WGETRC}
export WGETRC="${OUTPUT_DIR}/wgetrc"

## Change permissions of the WGETRC file so that only the owner is able to read and write to the file.
chmod 600 ${WGETRC}

## Now, execute wget and save the output to the cookie file.
${WGET} --secure-protocol=auto --save-cookies="${COOKIE_FILE}" --keep-session-cookies "https://updates.oracle.com/Orion/Services/download" -O /dev/null

## Save the patch languages and platforms into the file - $TMP1.
${WGET} --no-check-certificate --load-cookies=${COOKIE_FILE} "https://updates.oracle.com/Orion/SavedSearches/switch_to_simple" -q -O ${TMP1}

## Extract only the platforms and languages.
grep -A999 "<select name=plat_lang" ${TMP1} | grep "^<option" | egrep -v "selected" | awk -F "[\">]" '{print $2" - "$4}'
## Explanation of the above command:
## grep -A999 "<select name=plat_lang" ${TMP1}  ==> Search for this pattern "<select name=plat_lang" in the file - $TMP1 and print the next 999 lines just after the pattern matching line (-A999)
## grep "^<option" ==> Search for all lines that start with "<option"
## egrep -v "selected" ==> discard all lines matching the pattern "selected" (unlike grep, egrep allows providing multiple patterns in the same command)
## awk -F "[\">]" '{print $2" - "$4}' ==> Use two field delimiters - a double quote (") and greater than symbol (>) - and then print the 2nd and the 4th column.
