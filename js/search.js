var pairs = location.search.substring(1).split('&');
var title = '';
var cache = 'yes';
pairs.forEach(function (item) {
    if (item.split('=')[0] === 'title') {
        title = item.split('=')[1];
    } else if (item.split('=')[0] === 'cache') {
        cache = item.split('=')[1];
    }
});
var refresh_url = location.protocol + '//' + location.host + location.pathname + '?title=' + title + '&cache=no';
var refresh_element = document.getElementById("refresh");
refresh_element.href = refresh_url;
if (pairs[0].split('=')[0] === 'title') {
    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function() {
        var table = document.getElementById("result");
        var row;
        if (this.readyState === 4 && this.status === 200) {
            table.deleteRow(-1);
            row = table.insertRow(-1);
            var keys = [
                ['title', 'steam_url'],
                ['date'],
                ['genre'],
                ['metascore', 'metacritics_url'],
                ['reviews'],
                ['price', 'steamdb_url'],
                ['developer', 'developer_url']
            ];
            var text = '';
            var steamUrl = '';
            var response = this.response;
            keys.forEach(function(value, index) {
                var cell = row.insertCell(-1);
                var value1 = response[value[0]];
                if (value.length >= 2) {
                    var value2 = response[value[1]];
                    var link = document.createElement("a");
                    link.href = value2;
                    link.appendChild(document.createTextNode(value1));
                    cell.appendChild(link);
                    text += '=HYPERLINK("' + value2 + '";"' + value1 + '")';
                } else {
                    cell.appendChild(document.createTextNode(value1));
                    text += value1;
                }
                if (index < keys.length - 1) {
                    text += '\t'
                }
            });
            steamUrl = response['steam_url'];
            var imageURL = steamUrl.replace(/(http|https):\/\/store\.steampowered\.com\/app\//g,
                'https://steamcdn-a.akamaihd.net/steam/apps/')
                .replace(/\/?[^\/]*[^\/0-9]+[^\/]*\/?$/g, '/header.jpg');
            if (imageURL.indexOf('header.jpg') === -1)
                imageURL += 'header.jpg';
            document.getElementById('thumbnail-img').innerHTML = '<a href="' +
                steamUrl + '"><img style="width:324px" src="' + imageURL + '"</img></a><br><br>';
            var textArea = document.getElementById('output');
            textArea.value = text;
            textArea.onfocus = function() {
                textArea.select();
            };
            textArea.focus();
            document.title += ' - ' + response['title'];
        } else if (this.readyState === 4 && this.status === 403) {
            table.deleteRow(-1);
            row = table.insertRow(-1);
            var cell = row.insertCell(-1);
            cell.appendChild(document.createTextNode(this.response['error']));
        }
    };
    xhr.responseType = 'json';
    xhr.open('GET', 'https://apil1.semnil.com/steamGame?'
        + 'cache=' + encodeURIComponent(cache) + '&'
        + 'title=' + encodeURIComponent(title), true);
    xhr.send();
}
