#!/bin/bash

cd `dirname ${BASH_SOURCE:-$0}`

export LANG='ja_JP.UTF-8'
export LC_ALL='ja_JP.UTF-8'
export LC_MESSAGES='ja_JP.UTF-8'

TMP_PAGE_FILE=/tmp/tmp.json
HIST_FILE=/tmp/$(pwd | sed 's/\//./g').hist
GOOGLE_SEARCH_STR="https://www.googleapis.com/customsearch/v1?key=${GOOGLE_API_KEY}&cx=${GOOGLE_APP_ID}&q=allintitle%3A+steam+%3A+"
UA_OPTION="User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.121 Safari/537.36"
METACRITIC_STR="https://www.metacritic.com"


PARAMS=(`echo ${REQUEST_URI} | awk 'BEGIN { FS="?" ; } { print $2 }' | awk 'BEGIN { FS="&" ; } { print $1 }'`)
PARAM_KEY=`echo ${PARAMS[0]} | awk 'BEGIN { FS="=" ; } { print $1 }'`
PARAM_VAL=`echo ${PARAMS[0]} | awk 'BEGIN { FS="=" ; } { print $2 }'`

#echo "Content-type: application/json; charset=utf-8"
#echo ""

if [ "${PARAM_KEY}" != "title" ] ; then
    #echo "<p><b><font color=\"red\">Insufficient parameters.</font></b></p>"
    echo "{\"error\":\"Insufficient parameters.\"}"
    exit 0
fi

if [ "${IS_LAMBDA}" != "" ] ; then
    INPUT_STR=`echo ${PARAM_VAL} | python uridecode.py | tr "A-Z" "a-z" | sed 's/+/ /g'`
else
    INPUT_STR=`echo ${PARAM_VAL} | nkf --url-input -W | tr "A-Z" "a-z" | sed 's/+/ /g'`
fi
#echo "<!-- input string = ${INPUT_STR} -->"

if [ "${INPUT_STR}" = "" ] ; then
    #echo "<p><b><font color=\"red\">Information was not input.</font></b></p>"
    echo "{\"error\":\"Information was not input.\"}"
    exit 0
fi


expr "${INPUT_STR}" + 1 >/dev/null 2>&1
if [ $? -lt 2 ] ; then
    # make link url from AppId
    STEAM_LINK="\"https://store.steampowered.com/app/${INPUT_STR}/\""
elif echo ${INPUT_STR} | grep '^https:\/\/store.steampowered.com\/app\/[0-9]\+' >/dev/null 2>&1 ; then
    # input steam url
    STEAM_LINK=\"`echo ${INPUT_STR} | sed -e 's/\?[^\/]*$//g'`\"
else
    # search a steam page by the google
    QUERY=`echo ${INPUT_STR} | sed 's/-/ /g' | sed 's/　/ /g' | sed 's/ /+/g' | sed 's/:/%3A/g' | sed 's/&/%26/g' | sed 's/!/\\!/g' | sed 's/%20/+/g'`
    #echo "<!-- steam search query = ${QUERY} -->"
    SEARCH_URL="${GOOGLE_SEARCH_STR}${QUERY}"
    curl "${SEARCH_URL}" -o ${TMP_PAGE_FILE} 2>/dev/null
    STEAM_LINK=`cat ${TMP_PAGE_FILE} | grep "\"link\":" | grep 'https:\/\/store.steampowered.com\/app\/[0-9]\+' | head -n 1 | sed 's/^.*\"link\": //g' | sed 's/,.*//g' | sed 's/?.*"$/"/g'`
fi

URL=`echo ${STEAM_LINK} | awk 'BEGIN { FS="\""; } { print $2 }'`
URL="${URL}?cc=JP"
#echo "<!-- steam url = ${URL} -->"
#echo "<!-- steam page status"
STATUS=`curl -L -H 'Accept-Language: ja,en-US;q=0.8,en;q=0.6' ${URL} -o ${TMP_PAGE_FILE} -w '%{http_code}\n' -H 'Cookie: mature_content=1; birthtime=444927601; timezoneOffset=32400,0;' 2>/dev/null`
#echo ${STATUS}
#echo "-->"
if cat ${TMP_PAGE_FILE} | grep '"domain": "usageLimits"' >/dev/null 2>&1 ; then
    echo "{\"error\":\"API usage limits.\"}"
    exit 0
elif [ "${STATUS}" != "200" ] ; then
    #echo "<p><b><font color=\"red\">Can not open a steam page.</font></b></p>"
    echo "{\"error\":\"Can not open a steam page.\",\"search_result\":`cat ${TMP_PAGE_FILE} | tr -d '\n'`}"
    exit 0
fi

# save app id for the steamdb
APP_ID=`echo ${STEAM_LINK} | awk 'BEGIN { FS="/"; } { print $5 }' | tr -d '"'`
#echo "<!-- app_id = ${APP_ID} -->"

# get some params by a steam page
DISPLAY_TITLE=`cat ${TMP_PAGE_FILE} | grep "apphub_AppName" | sed 's/.*\">//g' | sed 's/<.*//g' | sed 's/[®™]//g' | sed -e 's/&trade;//g' | sed -e 's/amp;//g'`
if [ "${STATUS}" == "200" -a "${DISPLAY_TITLE}" = "" ] ; then
    # avoid the OMAKUNI
    URL=`echo ${STEAM_LINK} | awk 'BEGIN { FS="\""; } { print $2 }'`
    URL="${URL}?cc=us"
    #echo "<!-- steam url = ${URL} (avoid the OMAKUNI) -->"
    #echo "<!-- steam page status"
    STATUS=`curl -H 'Accept-Language: ja,en-US;q=0.8,en;q=0.6' ${URL} -o ${TMP_PAGE_FILE} -w '%{http_code}\n' -H 'Cookie: mature_content=1; birthtime=444927601; timezoneOffset=32400,0;' 2>/dev/null`
    #echo ${STATUS}
    #echo "-->"
    DISPLAY_TITLE=`cat ${TMP_PAGE_FILE} | grep "apphub_AppName" | sed 's/.*\">//g' | sed 's/<.*//g' | sed 's/[®™]//g' | sed -e 's/&trade;//g' | sed -e 's/amp;//g'`
    #if [ "${STATUS}" != "200" -o "${DISPLAY_TITLE}" != "" ] ; then
    #    echo "<p><b><font color=\"red\">This page have OMAKUNI in Japan.</font></b></p>"
    #fi
fi
#echo "<!-- display title = ${DISPLAY_TITLE} -->"
if [ "${STATUS}" == "200" -a "${DISPLAY_TITLE}" = "" ] ; then
    #echo "<p><b><font color=\"red\">Can not open a steam page.</font></b></p>"
    echo "{\"error\":\"Can not open a steam page.\"}"
    exit 0
fi
DATE=`cat ${TMP_PAGE_FILE} | grep "class=\"date\"" | sed 's/.*\">//g' | sed 's/日//g' | sed 's/<.*//g' | sed 's/年/\//g' | sed 's/月/\//g' | sed 's/\/$//g'`

GENRE=`cat ${TMP_PAGE_FILE} | grep ":\/\/store.steampowered.com\/genre\/" | grep -v "popup_menu_item" | grep -v "&gt; <a" | tail -n 1 | sed 's/<[^a\"]*> *//g' | sed 's/<[^>]*>//g' | tr -d "[:blank:]"`
GENRE=`echo ${GENRE} | sed 's/カジュアル//g' | sed 's/独立系開発会社//g' | sed 's/早期アクセス//g' | sed 's/MM（MassivelyMultiplayer）//g' | sed 's/アクションRPG/ARPG/g' | sed 's/シミュレーションRPG/SRPG/g' | sed 's/ハックアンドスラッシュ/ハクスラ/g' | sed 's/アクション/ACT/g' | sed 's/シューティング/STG/g' | tr -d '\r' | sed -E 's/,+/,/g' | sed -E 's/(^,|,$)//g' | sed 's/,/\//g' | sed 's/ACT\/RPG/ARPG/g'`
[ "${GENRE}" == "" ] && GENRE="ACT"

REVIEWS=`cat ${TMP_PAGE_FILE} | grep "game_review_summary" | grep "description" | tail -n 1 | sed 's/.*\">//g' | sed 's/<.*//g'`
echo ${REVIEWS} | grep "ユーザーレビュー" >/dev/null 2>&1 && REVIEWS=""
DEVELOPER=`cat ${TMP_PAGE_FILE} | grep "?developer=" | grep -v "/linkfilter/" | head -n 1 | sed 's/[^,]*\">//g' | sed 's/<.*//g' | sed -e 's/amp;//g'`
DEVELOPER_LINK=`cat ${TMP_PAGE_FILE} | grep "?developer=" | grep -v "/linkfilter" | head -n 1 | sed 's/[^,]*href=//g' | sed 's/>.*//g' | sed "s/ .*//g"`
if [ "${DEVELOPER}" = "" ] ; then
    DEVELOPER=`cat ${TMP_PAGE_FILE} | grep "/developer/" | grep -v "/linkfilter/" | head -n 1 | sed 's/[^,]*\">//g' | sed 's/<.*//g' | sed -e 's/amp;//g'`
    DEVELOPER_LINK=`cat ${TMP_PAGE_FILE} | grep "/developer/" | grep -v "/linkfilter/" | head -n 1 | sed 's/[^,]*href=//g' | sed 's/>.*//g' | sed "s/ .*//g"`
fi
if [ "${DEVELOPER}" = "" ] ; then
    DEVELOPER=`cat ${TMP_PAGE_FILE} | grep "/curator/" | grep -v "/linkfilter/" | head -n 1 | sed 's/[^,]*\">//g' | sed 's/<.*//g' | sed -e 's/amp;//g'`
    DEVELOPER_LINK=`cat ${TMP_PAGE_FILE} | grep "/curator/" | grep -v "/linkfilter/" | head -n 1 | sed 's/[^,]*href=//g' | sed 's/>.*//g' | sed "s/ .*//g"`
fi
META_LINK=`cat ${TMP_PAGE_FILE} | grep "game_area_metalink" | grep "href=" | sed 's/.*href=//g' | sed 's/ target=.*//g'`

if [ "`cat ${TMP_PAGE_FILE} | grep -v "bundle_base_discount" | grep 'class="discount_original_price"'`" == "" ] ; then
    # not discounted
    PRICE_LINE=`cat -n ${TMP_PAGE_FILE} | grep 'class="game_purchase_price' | head -n 1 | awk '{ print $1 }'`
    if [ "${PRICE_LINE}" != "" ] ; then
        PRICE_LINE_STR=`cat ${TMP_PAGE_FILE} | tail -n+${PRICE_LINE} | head -n 3 | grep "¥"`
        ORIGINAL_PRICE=`cat ${TMP_PAGE_FILE} | tail -n+${PRICE_LINE} | head -n 3 | grep "¥" | sed -e 's/.*¥ //g' | sed -e 's/[^0-9]*//g' | tr -d ','`
    fi
else
    # discounted
    ORIGINAL_PRICE=`cat ${TMP_PAGE_FILE} | grep 'class="discount_original_price"' | head -n 1 | sed -e 's/.*class="discount_original_price">//g' | sed 's/¥ //g' | sed -e 's/<.*//g' | sed 's/,//g'`
fi

# get price by a steamdb page
DB_LINK="\"https://steamdb.info/app/${APP_ID}/?cc=jp\""
#echo "<!-- steamdb url = ${DB_LINK} -->"
curl -b cc=jp -L "https://steamdb.info/app/${APP_ID}/" 2>/dev/null > ${TMP_PAGE_FILE}
PRICE_BLOCK=`cat -n ${TMP_PAGE_FILE} | grep 'id="js-price-history"' | awk '{ print $1 }'`
PRICE_LINE=`expr ${PRICE_BLOCK} + 6`
if [ "${PRICE_BLOCK}" != "" -a "${PRICE_LINE}" != "" ] ; then
    LOW_PRICE=`cat ${TMP_PAGE_FILE} | tail -n+${PRICE_LINE} | head -n 1 | sed 's/.*">¥ *//g' | sed 's/ *at.*//g' | sed 's/<\/.*//g'`
    if [ "${LOW_PRICE}" = "" ] ; then
        #echo "<!-- get USD price -->"
        PRICE_BLOCK=`cat -n ${TMP_PAGE_FILE} | grep 'class="price-line" data-cc="us"' | awk '{ print $1 }'`
        if [ "${ORIGINAL_PRICE}" = "" ] ; then
            PRICE_LINE=`expr ${PRICE_BLOCK} + 3`
            ORIGINAL_PRICE=`cat ${TMP_PAGE_FILE} | tail -n+${PRICE_LINE} | head -n 1 | sed -e 's/<[^>]*>//g' | tr -d ' '`
        fi
        PRICE_LINE=`expr ${PRICE_BLOCK} + 6`
        LOW_PRICE=`cat ${TMP_PAGE_FILE} | tail -n+${PRICE_LINE} | head -n 1 | sed -e 's/<[^>]*>//g' | sed -e 's/at.*//g' | tr -d ' '`
    fi
    if [ "${LOW_PRICE}" = "" ] ; then
        LOW_PRICE=${ORIGINAL_PRICE}
    fi
    [ "${ORIGINAL_PRICE}" = "" ] || PRICE_STR=${ORIGINAL_PRICE}/${LOW_PRICE}
else
    RESULT=`cat -n ${TMP_PAGE_FILE} | grep "octicon-cloud-download" | grep "Free"`
    if [ "${RESULT}" != "" ] ; then
        DB_LINK=""
        PRICE_STR="Free"
    else
        #echo "<p><b><font color=\"red\">Can not open a steamdb page.</font></b></p>"
        PRICE_STR=${ORIGINAL_PRICE}
    fi
fi


if [ "${META_LINK}" = "" ] ; then
    # search a metacritic page
    QUERY=`echo ${DISPLAY_TITLE} | sed -e 's/&amp;//g' | tr "A-Z" "a-z" | sed -E 's/- .* -$//g' | sed -E 's/:.*$//g' | sed -E 's/[^a-zA-Z0-9!-.:-@¥[-\`{-~ ]+.*//g' | sed 's/_/ /g' | sed -E 's/ +/-/g' | sed -E "s/([:\?\.&,\/]|-$|-dx$)//g" | sed -E 's/-+/+/g' | sed -E 's/\++/%20/g'`
    URL=`echo ${METACRITIC_STR}/search/game/${QUERY}/results\?plats\\\[3\\\]=1\&search_type=advanced`
    #echo "<!-- metacritic search query = ${QUERY} -->"
    curl "${URL}" -H "${UA_OPTION}" 2>/dev/null > ${TMP_PAGE_FILE}
    RESULT=`cat ${TMP_PAGE_FILE} | grep "href=\"/game/pc/" | head -n 1 | sed 's/^.* href="//g' | sed 's/".*$//g'`
    if [ "${RESULT}" != "" ] ; then
        URL=${METACRITIC_STR}${RESULT}
        META_LINK="\"${URL}\""
        #echo "<!-- metacritic url = ${URL} -->"
        #echo "<!-- metacritic page status"
        STATUS=`curl -L ${URL} -H "${UA_OPTION}" -o ${TMP_PAGE_FILE}  -w '%{http_code}\n' 2>/dev/null`
        #echo ${STATUS}
        #echo "-->"
    else
        METASCORE_STR="-"
    fi
else
    URL=`echo ${META_LINK} | awk 'BEGIN { FS="\""; } { print $2 }'`
    #echo "<!-- metacritic url = ${URL} -->"
    #echo "<!-- metacritic page status"
    STATUS=`curl -L ${URL} -H "${UA_OPTION}" -o ${TMP_PAGE_FILE}  -w '%{http_code}\n' 2>/dev/null`
    #echo ${STATUS}
    #echo "-->"
fi
if [ "${STATUS}" != "200" ] ; then
    #echo "<p><b><font color=\"red\">Can not open a metacritic page.</font></b></p>"
    METASCORE_STR=""
else
    # get two scores from the metacritic
    META_SCORE=`cat ${TMP_PAGE_FILE} | grep "ratingValue" | tail -n 1 | sed 's/.*\">//g' | sed 's/<\/.*//g'`
    USER_SCORE=`cat ${TMP_PAGE_FILE} | grep "metascore_w user large" | head -n 1 | sed 's/.*\">//g' | sed 's/<\/.*//g'`
    METASCORE_STR=${META_SCORE:="tbd"}/${USER_SCORE:="tbd"}
fi


rm -rf ${TMP_PAGE_FILE}


# formatted output
echo "{"
echo -n "\"title\":\""
echo -n ${DISPLAY_TITLE}
echo "\","
echo "\"steam_url\":${STEAM_LINK},"
echo "\"date\":\"${DATE}\","
echo "\"genre\":\"${GENRE}\","
echo "\"metascore\":\"${METASCORE_STR}\","
if [ "${META_LINK}" != "" ] ; then
    echo "\"metacritics_url\":${META_LINK},"
else
    echo "\"metacritics_url\":\"\","
fi
echo "\"reviews\":\"${REVIEWS}\","
echo "\"price\":\"${PRICE_STR}\","
if [ "${DB_LINK}" != "" ] ; then
    echo "\"steamdb_url\":${DB_LINK},"
else
    echo "\"steamdb_url\":\"\","
fi
echo -n "\"developer\":\""
echo -n ${DEVELOPER}
echo "\","
if [ "${DEVELOPER_LINK}" != "" ] ; then
    echo "\"developer_url\":$DEVELOPER_LINK"
else
    echo "\"developer_url\":\"\""
fi
echo "}"
