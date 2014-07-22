#!/bin/bash
source="$1"
dest="$2"
msg=$(git --no-pager log HEAD -1 "${source}")
echo """/**
${msg}
**/""" | cat - $dest > "${dest}.tmp" && mv "${dest}.tmp" $dest
