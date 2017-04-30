#!/bin/bash

export LANG='ja_JP.UTF-8'
export LC_ALL='ja_JP.UTF-8'
export LC_MESSAGES='ja_JP.UTF-8'

HIST_FILE=/tmp/$(cd $(dirname ${BASH_SOURCE:-$0}); pwd | sed 's/\//./g').hist

echo "Content-type: application/javascript"
echo "Cache-Control: no-cache"
echo ""

echo "var table = document.getElementById('hist');"
echo "var items = ["
IFS=$'\n'
for line in `tac ${HIST_FILE} | awk '!a[$0]++' | head -n 25`
do
    IFS='	'
    set -- ${line}
    echo "[\"$2\",\"$1\"],"
done
echo "]"

echo "items.forEach(function(value) {"
echo "var row = table.insertRow(-1);"
echo "var cell = row.insertCell(-1);"
echo "cell.innerHTML = \"<a href=\\\"\" + value[0] + \"\\\">\" + decodeURI(value[1]) + \"</a>\""
echo "});"
