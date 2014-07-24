#!/bin/bash
source="$1"
dest="$2"
msg=$(git --no-pager log HEAD -1 "${source}")
ext="${dest##*.}"
if [ "$ext" == "js" ]; then
    open_comment="/**"
    close_commet="**/"
elif [ "$ext" == "html" ]; then
    open_comment="<!--"
    close_commet="-->" 
else
    echo "Unknown extension" > /dev/stderr
    exit -1
fi

echo """${open_comment}
${msg}
${close_commet}""" | cat - $dest > "${dest}.tmp" && mv "${dest}.tmp" $dest
