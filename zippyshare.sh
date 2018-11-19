#!/bin/bash
# @Description: zippyshare.com file download script
# @Author: Live2x
# @Revode: JeelsBoobz
# @URL: https://github.com/img2tab/zippyshare
# @Version: 201811270001
# @Date: 2018-11-19
# @Usage: ./zippyshare.sh url

urldecode() {
    local url_encoded="${1//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}

if [ -z "${1}" ]
then
    echo "usage: ${0} url"
    echo "batch usage: ${0} url-list.txt"
    echo "url-list.txt is a file that contains one zippyshare.com url per line"
    exit
fi

function zippydownload()
{
    prefix="$( echo -n "${url}" | cut -c "11,12,31-38" | sed -e 's/[^a-zA-Z0-9]//g' )"
    cookiefile="${prefix}-cookie.tmp"
    infofile="${prefix}-info.tmp"

    # loop that makes sure the script actually finds a filename
    filename=""
    retry=0
    while [ -z "${filename}" -a ${retry} -lt 10 ]
    do
        let retry+=1
        rm -f "${cookiefile}" 2> /dev/null
        rm -f "${infofile}" 2> /dev/null
        wget -O "${infofile}" "${url}" \
        --cookies=on \
        --keep-session-cookies \
        --save-cookies="${cookiefile}" \
        --quiet
        filename="$( grep 'og:title' "${infofile}" | grep -Po '(?<=<meta property="og:title" content=").*?(?= " />)')"
    done

    if [ "${retry}" -ge 10 ]
    then
        echo "could not download file"
        exit 1
    fi

    # Get cookie
    if [ -f "${cookiefile}" ]
    then
        jsessionid="$( cat "${cookiefile}" | grep "JSESSIONID" | cut -f7)"
    else
        echo "can't find cookie file for ${prefix}"
        exit 1
    fi

    if [ -f "${infofile}" ]
    then
        # Get url algorithm
        dlbutton="$( grep 'poster=true&amp;time=' "${infofile}" | grep -Po '(?<=poster=true&amp;time=).*?(?=">)')"
        if [ -n "${dlbutton}" ]
        then
           algorithm=$((${dlbutton:(-3)} + 1 + 2 + 3 + 4 + 5 / 5 ))
        else
           echo "could not get zippyshare url algorithm"
           exit 1
        fi

        a="$( echo $(( ${algorithm} )) )"
        # Get ref, server, id
        ref="$( cat "${infofile}" | grep 'property="og:url"' | cut -d'"' -f4 | grep -o "[^ ]\+\(\+[^ ]\+\)*" )"

        server="$( echo "${ref}" | cut -d'/' -f3 )"

        id="$( echo "${ref}" | cut -d'/' -f5 )"
    else
        echo "can't find info file for ${prefix}"
        exit 1
    fi

    # Build download url
    dl="https://${server}/d/${id}/${a}/${filename}"

    # Set browser agent
    agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.87 Safari/537.36"

    echo "$( urldecode ${filename})"

    # Start download file
    wget -c -O "$( urldecode ${filename})" "${dl}" \
    -q --show-progress \
    --referer="${ref}" \
    --cookies=off --header "Cookie: JSESSIONID=${jsessionid}" \
    --user-agent="${agent}"
    rm -f "${cookiefile}" 2> /dev/null
    rm -f "${infofile}" 2> /dev/null
}

if [ -f "${1}" ]
then
    for url in $( cat "${1}" | sed 's/\r$//' | grep -i 'zippyshare.com' )
    do
        zippydownload "${url}"
    done
else
    url="${1}"
    zippydownload "${url}"
fi
