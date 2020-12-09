const http = require('http');
const express = require('express');
const bodyParser = require('body-parser');
const redis = require('redis');
const axios = require('axios');

const app = express();
const client = redis.createClient({
	host: 'rs',
	port: 6379
});

let port = process.env.PORT || 8080;
let host = process.env.HOST || 'localhost';

client.on('connect', () => {
	console.log('Succesfully connected to redis');
});

client.on('error', (error) => {
	console.log('Error: ' + error);
});

/*
Registers http server to the load balancer server.
The information of the http server is sent in the body of the request.
*/
/*function registerToLoadBalancer() {
	axios.post('http://lb:7999/register', {
		url: `http://${host}:${port}`
	}).then(res => {
		console.log('Register ok');
	}).catch(err => {
		console.log('Register error');
	});
}*/
/*
// HOST will be set when running containers
if (host !== 'localhost') {
	registerToLoadBalancer();
}
*/
app.use(bodyParser.json());

function countFactorial(num) {
	let n = Number(num);
	let res = 1;
	for (let i = 2; i <= n; i++) {
		res *= i;
	}
	return res;
}

app.get('/random', (req, res) => {
	console.log('request to /random');
	client.send_command('randomkey', null, (err, r1) => {
		if (r1) {
			client.get(r1, (e, r) => {
				console.log('res: ' + r);
				if (r) {
					let factorial = countFactorial(r);
					res.status(200).json(`Factorial of ${r} = ${factorial}`);
				} else {
					res.status(404);
				}
			});
		}
	});
});

const server = http.createServer(app);

server.listen(port, () => {
	console.log('HTTP server running on port ' + port);
});
