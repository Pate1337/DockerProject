const express = require('express');
const bodyParser = require('body-parser');
const http = require('http');
const request = require('request');

const app = express();

app.use(bodyParser.json());

let servers = [];
let cur = 0;

function addToServers(host) {
	if (servers.indexOf(host) == -1) {
		console.log(`Added ${host} to servers`)
		servers.push(host);
	}
}

/*
When ever a http server starts running, it sends it's information to /register.

The cases when http server disconnects are not handled:
  - Would still keep redirecting requests to it
*/
app.post('/register', (req, res) => {
	let body = req.body;
	addToServers(body.url);
	return res.status(200).json('OK');
});

/*
This method simply takes turns on which http server it redirects the requests
*/
app.get('/random', (req, res) => {
	req.pipe(request({ url: servers[cur] + req.url }).on('error', err => {
		res.status(500).send(err.message);
	})).pipe(res);
	cur = (cur + 1) % servers.length;
});

const server = http.createServer(app);

server.listen(7999, () => {
	console.log('LoadBalancer listening to port 7999');
});
