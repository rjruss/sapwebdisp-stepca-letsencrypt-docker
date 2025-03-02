#!/bin/bash


read -r -p "Enter S-ID: " sid
read -r -s -p "Enter S-ID password: " password


download_sap_files () {

    echo "downloading ${1}"
    curl -L -b cookies.txt  \
        -u "$sid:$password" \
        -o "${1}" \
        "https://softwaredownloads.sap.com/file/${2}"

    file_check=$(file -b --mime "${1}")

    if [[ $file_check == *"charset=binary"* ]]; then
        echo "initial check the file downloaded is binary"
    else
        echo "Download failed to download binary file exiting."
        exit 2
    fi

}

download_sap_files "SAPCAR" "0020000000498472024"
download_sap_files "SAPWEBDISP_SP_235-80007304.SAR" "0020000001532182023"

#https://softwaredownloads.sap.com/file/0020000000498472024
#https://softwaredownloads.sap.com/file/0020000001532182023
