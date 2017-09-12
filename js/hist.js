var xhr = new XMLHttpRequest();
xhr.onreadystatechange = function() {
    if (this.readyState === 4 && this.status === 200) {
        var table = document.getElementById('hist');
        table.deleteRow(-1);
        var items = this.response;
        items.forEach(function(value) {
            var row = table.insertRow(-1);
            var cell = row.insertCell(-1);
            cell.innerHTML = "<a href=\"" + value[0] + "\">" + decodeURI(value[1]) + "</a>"
        });
    }
};
xhr.responseType = 'json';
xhr.open('GET', 'https://apil1.semnil.com/historySteamGame', true);
xhr.send();
