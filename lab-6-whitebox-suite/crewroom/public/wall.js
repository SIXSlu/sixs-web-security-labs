'use strict';
// Crew wall front-end. Pulls the notice feed from the REST API and pins
// the notes onto the wall. The console script keeps the supervisor tap
// in localStorage; the wall shows the session badge when one is present.

function api(method, url, data, cb) {
    var x = new XMLHttpRequest();
    x.open(method, url);
    x.onreadystatechange = function () {
        if (x.readyState !== 4) return;
        var body = null;
        try { body = x.responseText ? JSON.parse(x.responseText) : null; }
        catch (e) { /* non-JSON response - leave body null */ }
        cb(x.status, body);
    };
    x.setRequestHeader('content-type', 'application/json');
    x.send(data ? JSON.stringify(data) : null);
}

function esc(s) {
    return String(s).replace(/[&<>"]/g, function (c) {
        return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c];
    });
}

function refresh() {
    api('GET', '/api/notices', null, function (status, data) {
        if (status !== 200) return;
        var token = localStorage.getItem('crewroom_token');
        var user = localStorage.getItem('crewroom_user');
        var who = document.getElementById('who');
        who.textContent = token
            ? 'signed in as ' + (user || 'stationmaster') + ' (supervisor console)'
            : 'not signed in';

        // Pin each note onto the wall. Notices are free text - the wall
        // renders whatever the crew pinned, formatting included.
        document.getElementById('wall').innerHTML = data.notices.map(function (n) {
            return '<article class="notice">'
                + '<header>note #' + n.id + ' &mdash; ' + esc(n.author)
                + ' &mdash; ' + n.at + '</header>'
                + '<div class="body">' + n.body + '</div>'
                + '</article>';
        }).join('');
    });
}

document.getElementById('pin').addEventListener('submit', function (ev) {
    ev.preventDefault();
    api('POST', '/api/notices', {
        author: document.getElementById('author').value,
        body: document.getElementById('body').value,
    }, function (status) {
        if (status === 201) {
            document.getElementById('body').value = '';
            refresh();
        }
    });
});

refresh();
setInterval(refresh, 10000);