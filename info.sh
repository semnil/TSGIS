#!/bin/bash

export LANG='ja_JP.UTF-8'
export LC_ALL='ja_JP.UTF-8'
export LC_MESSAGES='ja_JP.UTF-8'

TMP_PAGE_FILE=/tmp/tmp.html
GOOGLE_SEARCH_STR="https://www.googleapis.com/customsearch/v1?key=${GOOGLE_API_KEY}&cx=${GOOGLE_APP_ID}&q="


PARAMS=(`echo ${REQUEST_URI} | awk 'BEGIN { FS="?" ; } { print $2 }' | awk 'BEGIN { FS="&" ; } { print $1 }'`)
PARAM_KEY=`echo ${PARAMS[0]} | awk 'BEGIN { FS="=" ; } { print $1 }'`
PARAM_VAL=`echo ${PARAMS[0]} | awk 'BEGIN { FS="=" ; } { print $2 }'`

echo "Content-type: text/html"
echo ""
echo "<!DOCTYPE html>"
echo "<html>"
echo "<head>"
echo "<meta charset="UTF-8">"
echo "<title>収集結果</title>"
echo "</head>"
echo "<body>"

if [ "$PARAM_KEY" != "title" ] ; then
    echo "error"
    echo "</body>"
    echo "</html>"
    exit
fi

TITLE=`echo ${PARAM_VAL} | nkf --url-input | sed 's/+/ /g'`

if [ "$TITLE" = "" ] ; then
    echo "error"
    echo "</body>"
    echo "</html>"
    exit
fi


# search a steam page by the google
QUERY=`echo ${TITLE} | sed 's/-/ /g' | sed 's/://g' | sed 's/ /+/g' | sed 's/%/%25/g'`
STEAM_LINK=`curl "${GOOGLE_SEARCH_STR}steam+${QUERY}" 2>/dev/null | jq '.items[].link' | head -n 1 | sed 's/\?.*"/"/g'`
URL=`echo ${STEAM_LINK} | awk 'BEGIN { FS="\""; } { print $2 }'`
URL="${URL}?l=japanese"
curl -b timezoneOffset=32400,0 -L ${URL} 2>/dev/null > ${TMP_PAGE_FILE}

# save app id for the steamdb
APP_ID=`echo ${STEAM_LINK} | awk 'BEGIN { FS="/"; } { print $5 }'`

# get some params by a steam page
DISPLAY_TITLE=`cat ${TMP_PAGE_FILE} | grep "apphub_AppName" | sed 's/.*\">//g' | sed 's/<.*//g' | sed 's/[®™]//g'`
DATE=`cat ${TMP_PAGE_FILE} | grep "class=\"date\"" | sed 's/.*\">//g' | sed 's/日.*//g' | sed 's/年/\//g' | sed 's/月/\//g' | sed 's/日//g'`
GENRE=`cat ${TMP_PAGE_FILE} | grep "\/genre\/" | grep -v "popup_menu_item" | tail -n 1 | sed 's/<[^a\"]*> *//g' | sed 's/<[^>]*>//g' | tr -d "[:blank:]"`
REVIEWS=`cat ${TMP_PAGE_FILE} | grep "game_review_summary" | grep "description" | tail -n 1 | sed 's/.*\">//g' | sed 's/<.*//g'`
DEVELOPER=`cat ${TMP_PAGE_FILE} | grep "?developer=" | head -n 1 | sed 's/.*\">//g' | sed 's/<.*//g'`
META_LINK=`cat ${TMP_PAGE_FILE} | grep "game_area_metalink" | sed 's/.*href=//g' | sed 's/ target=.*//g'`

# get price by a steamdb page
curl -L "https://steamdb.info/app/${APP_ID}/" 2>/dev/null > ${TMP_PAGE_FILE}
PRICE_LINE=`cat -n ${TMP_PAGE_FILE} | grep 'class="price-line" data-cc="jp"' | awk '{ print $1 }'`
NOW_PRICE=`cat ${TMP_PAGE_FILE} | tail -n+${PRICE_LINE} | head -n 7 | grep 'data-sort="0"' | sed 's/.*">¥ *//g' | sed 's/<.*//g' | sed 's/ *at.*//g'`
LOW_PRICE=`cat ${TMP_PAGE_FILE} | tail -n+${PRICE_LINE} | head -n 7 | grep 'title' | sed 's/.*">¥ *//g' | sed 's/ *at.*//g'`
[ "$LOW_PRICE" = "" ] && LOW_PRICE=${NOW_PRICE}
[ "$NOW_PRICE" = "" ] || PRICE_STR=${NOW_PRICE}/${LOW_PRICE}


# search a steam page by the google
curl -L "${GOOGLE_SEARCH_STR}metacritic+${QUERY}" 2>/dev/null > ${TMP_PAGE_FILE}
[ "$META_LINK" = "" ] && META_LINK=`cat ${TMP_PAGE_FILE} | jq '.items[].link' | grep "metacritic.com" | head -n 1`

URL=`echo ${META_LINK} | awk 'BEGIN { FS="\""; } { print $2 }'`
curl -L ${URL} -H 'Referer: https://www.google.co.jp/' -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.95 Safari/537.36' 2>/dev/null > ${TMP_PAGE_FILE}

# get two scores from the metacritic
META_SCORE=`cat ${TMP_PAGE_FILE} | grep "ratingValue" | sed 's/.*\">//g' | sed 's/<\/.*//g'`
USER_SCORE=`cat ${TMP_PAGE_FILE} | grep "metascore_w user large" | head -n 1 | sed 's/.*\">//g' | sed 's/<\/.*//g'`


# search a developer site by the google
QUERY=`echo ${DEVELOPER} | sed 's/ /+/g'`
DEVELOPER_LINK=`curl -L "${GOOGLE_SEARCH_STR}${QUERY}" 2>/dev/null | jq '.items[].link' | grep -v "wikipedia" | head -n 1`


rm -rf ${TMP_PAGE_FILE}


# formated output
#echo -e $TITLE\\t$DATE\\t$GENRE\\t${META_SCORE:="tbd"}/${USER_SCORE:="tbd"}\\t$REVIEWS\\t$PRICE_STR\\t=hyperlink\($STEAM_LINK\;\"Steam\"\)\\t=hyperlink\($DEVELOPER_LINK\;\"$DEVELOPER\"\)
echo "<table border=1>"

echo "<tr>"
echo "<th></th>"
echo "<th>title</th>"
echo "<th>date</th>"
echo "<th>genre</th>"
echo "<th>metascore</th>"
echo "<th>reviews</th>"
echo "<th>price</th>"
echo "<th>store</th>"
echo "<th>developer</th>"
echo "</tr>"

echo "<tr>"
echo "<td></td>"
echo "<td>$DISPLAY_TITLE</td>"
echo "<td>$DATE</td>"
echo "<td>$GENRE</td>"
echo "<td>${META_SCORE:="tbd"}/${USER_SCORE:="tbd"}</td>"
echo "<td>$REVIEWS</td>"
echo "<td>$PRICE_STR</td>"
echo "<td><a href=$STEAM_LINK>Steam</a></td>"
echo "<td><a href=$DEVELOPER_LINK>$DEVELOPER</a></td>"
echo "</tr>"

echo "<tr>"
echo "<td>for spreadsheet</td>"
echo "<td>$DISPLAY_TITLE</td>"
echo "<td>$DATE</td>"
echo "<td>$GENRE</td>"
echo "<td>${META_SCORE:="tbd"}/${USER_SCORE:="tbd"}</td>"
echo "<td>$REVIEWS</td>"
echo "<td>$PRICE_STR</td>"
echo "<td>=hyperlink($STEAM_LINK;\"Steam\")</td>"
echo "<td>=hyperlink($DEVELOPER_LINK;\"$DEVELOPER\")</td>"
echo "</tr>"

echo "</table>"



echo "</body>"
echo "</html>"
