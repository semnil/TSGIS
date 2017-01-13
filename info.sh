#!/bin/bash

export LANG='ja_JP.UTF-8'
export LC_ALL='ja_JP.UTF-8'
export LC_MESSAGES='ja_JP.UTF-8'

TMP_PAGE_FILE=/tmp/tmp.json
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

INPUT_STR=`echo ${PARAM_VAL} | nkf --url-input | tr "A-Z" "a-z" | sed 's/+/ /g'`
echo "<!-- input string = ${INPUT_STR} -->"

if [ "$INPUT_STR" = "" ] ; then
    echo "error"
    echo "</body>"
    echo "</html>"
    exit
fi


expr "$INPUT_STR" + 1 >/dev/null 2>&1
if [ $? -lt 2 ] ; then
    # make link url from AppId
    STEAM_LINK="\"http://store.steampowered.com/app/$INPUT_STR/\""
elif echo ${INPUT_STR} | grep '^http:\/\/store.steampowered.com\/app\/[0-9]\+' >/dev/null 2>&1 ; then
    # input steam url
    STEAM_LINK=\"`echo ${INPUT_STR} | sed -e 's/\?[^\/]*$//g'`\"
else
    # search a steam page by the google
    QUERY=`echo ${INPUT_STR} | sed 's/-/ /g' | sed 's/://g' | sed 's/ /+/g' | sed 's/%/%25/g'`
    echo "<!-- steam search query = $QUERY -->"
    STEAM_LINK=`curl "${GOOGLE_SEARCH_STR}steam+${QUERY}" 2>/dev/null | jq '.items[].link' | grep "store.steampowered.com/app" | head -n 1 | sed 's/\?.*"/"/g'`
fi

URL=`echo ${STEAM_LINK} | awk 'BEGIN { FS="\""; } { print $2 }'`
URL="${URL}?l=japanese"
echo "<!-- steam url = ${URL} -->"
echo "<!-- steam page status"
STATUS=`curl -b timezoneOffset=32400,0 ${URL} -o ${TMP_PAGE_FILE} -w '%{http_code}\n' 2>/dev/null`
echo ${STATUS}
echo "-->"
[ "${STATUS}" != "200" ] && echo '<p><b><font color="red">Can not open a steam page.</font></b></p>'

# save app id for the steamdb
APP_ID=`echo ${STEAM_LINK} | awk 'BEGIN { FS="/"; } { print $5 }'`
echo "<!-- app_id = ${APP_ID} -->"

# get some params by a steam page
DISPLAY_TITLE=`cat ${TMP_PAGE_FILE} | grep "apphub_AppName" | sed 's/.*\">//g' | sed 's/<.*//g' | sed 's/[®™]//g'`
[ "${STATUS}" == "200" -a "$DISPLAY_TITLE" = "" ] && echo '<p><b><font color="red">Can not open a steam page.</font></b></p>'
DATE=`cat ${TMP_PAGE_FILE} | grep "class=\"date\"" | sed 's/.*\">//g' | sed 's/日.*//g' | sed 's/年/\//g' | sed 's/月/\//g' | sed 's/日//g'`

GENRE=`cat ${TMP_PAGE_FILE} | grep "\/genre\/" | grep -v "popup_menu_item" | tail -n 1 | sed 's/<[^a\"]*> *//g' | sed 's/<[^>]*>//g' | tr -d "[:blank:]"`
GENRE=`echo ${GENRE} | sed 's/カジュアル//g' | sed 's/独立系開発会社//g' | sed 's/早期アクセス//g' | sed 's/MM（MassivelyMultiplayer）//g' | tr -d '\r' | sed -e 's/,\+/,/g' | sed 's/^,//g' | sed 's/,$//g' | sed 's/,/\//g'`

REVIEWS=`cat ${TMP_PAGE_FILE} | grep "game_review_summary" | grep "description" | tail -n 1 | sed 's/.*\">//g' | sed 's/<.*//g'`
DEVELOPER=`cat ${TMP_PAGE_FILE} | grep "?developer=" | head -n 1 | sed 's/.*\">//g' | sed 's/<.*//g'`
META_LINK=`cat ${TMP_PAGE_FILE} | grep "game_area_metalink" | sed 's/.*href=//g' | sed 's/ target=.*//g'`

if [ "`cat ${TMP_PAGE_FILE} | grep 'class="discount_original_price"'`" == "" ] ; then
    # not discounted
    PRICE_LINE=`cat -n ${TMP_PAGE_FILE} | grep 'class="game_purchase_price' | head -n 1 | awk '{ print $1 }'`
    if [ "$PRICE_LINE" != "" ] ; then
        PRICE_LINE_STR=`cat ${TMP_PAGE_FILE} | tail -n+${PRICE_LINE} | head -n 3 | grep "¥"`
        ORIGINAL_PRICE=`cat ${TMP_PAGE_FILE} | tail -n+${PRICE_LINE} | head -n 3 | grep "¥" | sed -e 's/.*¥ //g' | sed -e 's/[^0-9]*//g' | tr -d ','`
    fi
else
    # discounted
    ORIGINAL_PRICE=`cat ${TMP_PAGE_FILE} | grep 'class="discount_original_price"' | head -n 1 | sed -e 's/.*class="discount_original_price">¥ //g' | sed -e 's/<.*//g' | sed 's/,//g'`
fi

# get price by a steamdb page
DB_LINK="\"https://steamdb.info/app/${APP_ID}/?cc=jp\""
echo "<!-- steamdb url = ${DB_LINK} -->"
curl -b cc=jp -L "https://steamdb.info/app/${APP_ID}/" 2>/dev/null > ${TMP_PAGE_FILE}
PRICE_LINE=`cat -n ${TMP_PAGE_FILE} | grep 'id="js-price-history"' | awk '{ print $1 }'`
if [ "${PRICE_LINE}" != "" ] ; then
    LOW_PRICE=`cat ${TMP_PAGE_FILE} | tail -n+${PRICE_LINE} | head -n 6 | grep 'title' | sed 's/.*">¥ *//g' | sed 's/ *at.*//g'`
    if [ "$LOW_PRICE" = "" -a "$ORIGINAL_PRICE" = "" ] ; then
        echo "<!-- get USD price -->"
        PRICE_LINE=`cat -n ${TMP_PAGE_FILE} | grep 'class="price-line" data-cc="us"' | awk '{ print $1 }'`
        ORIGINAL_PRICE=`cat ${TMP_PAGE_FILE} | tail -n+${PRICE_LINE} | head -n 6 | grep "\\\\$" | head -n 1 | sed -e 's/<[^>]*>//g' | tr -d ' '`
        LOW_PRICE=`cat ${TMP_PAGE_FILE} | tail -n+${PRICE_LINE} | head -n 6 | grep 'title' | sed -e 's/<[^>]*>//g' | sed -e 's/at.*//g' | tr -d ' '`
    elif [ "$LOW_PRICE" = "" ] ; then
        LOW_PRICE=${ORIGINAL_PRICE}
    fi
    [ "$ORIGINAL_PRICE" = "" ] || PRICE_STR=${ORIGINAL_PRICE}/${LOW_PRICE}
else
    echo '<p><b><font color="red">Can not open a steamdb page.</font></b></p>'
    PRICE_STR=${ORIGINAL_PRICE}
fi


if [ "$META_LINK" = "" ] ; then
    META_TITLE=`echo ${DISPLAY_TITLE} | tr "A-Z" "a-z" | sed 's/://g' | sed "s/'//g" | sed 's/_/ /g' | sed 's/ /-/g'`
    # generate a metacritic page URL from title
    URL="http://www.metacritic.com/game/pc/$META_TITLE"
    META_LINK="\"$URL\""
    echo "<!-- metacritic url = ${URL} -->"
    echo "<!-- metacritic page status"
    STATUS=`curl -L ${URL} -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.95 Safari/537.36' -o ${TMP_PAGE_FILE}  -w '%{http_code}\n' 2>/dev/null`
    echo ${STATUS}
    echo "-->"

    if [ "${STATUS}" != "200" ] ; then
        # search a metacritic page by the google
        QUERY=`echo ${DISPLAY_TITLE} | tr "A-Z" "a-z" | sed 's/://g' | sed "s/'//g" | sed 's/ /+/g' | sed 's/%/%25/g'`
        curl -L "${GOOGLE_SEARCH_STR}metacritic+${QUERY}+pc" 2>/dev/null > ${TMP_PAGE_FILE}
        META_LINK=`cat ${TMP_PAGE_FILE} | jq '.items[].link' | grep "metacritic.com/game/pc" | grep ${META_TITLE} | head -n 1`
        URL=`echo ${META_LINK} | awk 'BEGIN { FS="\""; } { print $2 }'`
        echo "<!-- metacritic url = ${URL} -->"
        echo "<!-- metacritic page status"
        STATUS=`curl -L ${URL} -H 'Referer: https://www.google.co.jp/' -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.95 Safari/537.36' -o ${TMP_PAGE_FILE}  -w '%{http_code}\n' 2>/dev/null`
        echo ${STATUS}
        echo "-->"
    fi
else
    URL=`echo ${META_LINK} | awk 'BEGIN { FS="\""; } { print $2 }'`
    echo "<!-- metacritic url = ${URL} -->"
    echo "<!-- metacritic page status"
    STATUS=`curl -L ${URL} -H 'Referer: https://www.google.co.jp/' -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.95 Safari/537.36' -o ${TMP_PAGE_FILE}  -w '%{http_code}\n' 2>/dev/null`
    echo ${STATUS}
    echo "-->"
fi
if [ "${STATUS}" != "200" ] ; then
    echo '<p><b><font color="red">Can not open a metacritic page.</font></b></p>'
    METASCORE_STR=""
else
    # get two scores from the metacritic
    META_SCORE=`cat ${TMP_PAGE_FILE} | grep "ratingValue" | sed 's/.*\">//g' | sed 's/<\/.*//g'`
    USER_SCORE=`cat ${TMP_PAGE_FILE} | grep "metascore_w user large" | head -n 1 | sed 's/.*\">//g' | sed 's/<\/.*//g'`
    METASCORE_STR=${META_SCORE:="tbd"}/${USER_SCORE:="tbd"}
fi


if [ "$DEVELOPER" != "" ] ; then
    # search a developer site by the google
    QUERY=`echo ${DEVELOPER} | sed 's/&amp;/%26/g' | sed 's/ /+/g' | sed 's/\++/+/g'`
    echo "<!-- developer query = ${QUERY} -->"
    DEVELOPER_LINK=`curl -L "${GOOGLE_SEARCH_STR}${QUERY}" 2>/dev/null | jq '.items[].link' | grep -v "wikipedia" | grep -v "twitter" | head -n 1`
fi

rm -rf ${TMP_PAGE_FILE}


# formatted output
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
[ "$META_LINK" != "" ] && echo "<td><a href=$META_LINK>$METASCORE_STR</a></td>" || echo "<td>$METASCORE_STR</td>"
echo "<td>$REVIEWS</td>"
[ "$DB_LINK" != "" ] && echo "<td><a href=$DB_LINK>$PRICE_STR</a></td>" || echo "<td>$PRICE_STR</td>"
echo "<td><a href=$STEAM_LINK>Steam</a></td>"
[ "$DEVELOPER" == "" ] && echo "<td></td>" || echo "<td><a href=$DEVELOPER_LINK>$DEVELOPER</a></td>"
echo "</tr>"

echo "<tr>"
echo "<td>for spreadsheet</td>"
echo "<td>$DISPLAY_TITLE</td>"
echo "<td>$DATE</td>"
echo "<td>$GENRE</td>"
echo "<td>$METASCORE_STR</td>"
echo "<td>$REVIEWS</td>"
echo "<td>$PRICE_STR</td>"
echo "<td>=hyperlink($STEAM_LINK;\"Steam\")</td>"
[ "$DEVELOPER" == "" ] && echo "<td></td>" || echo "<td>=hyperlink($DEVELOPER_LINK;\"$DEVELOPER\")</td>"
echo "</tr>"

echo "</table>"



echo "</body>"
echo "</html>"
