var xhr = new XMLHttpRequest();
xhr.onreadystatechange = function() {
    if (this.readyState === 4 && this.status === 200) {
        var hist = document.getElementById('hist');
        hist.innerHTML = "";
        var items = this.response;
        items.forEach(function(value) {
            var fontSize = (value[2] * 10 + 100) <= 200 ? (value[2] * 10 + 100) : 200;
            hist.innerHTML += "&nbsp;&nbsp;<a href=\"" + value[0] + "\" style=\"font-size:" + fontSize + "%\">" + decodeURI(value[1]) + "</a>"
        });
    }
};
xhr.responseType = 'json';
xhr.open('GET', 'https://apil1.semnil.com/historySteamGame', true);
xhr.send();
