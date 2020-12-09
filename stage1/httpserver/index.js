/*
This file is the http server used for the scripts:
- stage1/execute_stage1.sh
- stage2/docker_compose.sh
*/

const http = require('http');
const express = require('express');
const bodyParser = require('body-parser');
const redis = require('redis');
const axios = require('axios');

const app = express();

/*
The host 'rs' can be used, when there is a container named 'rs' defined
in the same network.

docker-compose.yml does it automatically in stage2.

In stage1 the option --net=<network_name> must be shared with httpserver container and
redis container.
*/
const client = redis.createClient({
	host: 'rs',
	port: 6379
});

/*
ENV variables are defined in docker-compose.yml for each instance of httpserver containers.

With "docker run" the option -e "HOST=<host_name>" -e "PORT=<port>" can be given.
*/
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
function registerToLoadBalancer() {
	axios.post('http://lb:7999/register', {
		url: `http://${host}:${port}`
	}).then(res => {
		console.log('Register ok');
	}).catch(err => {
		console.log('Register error');
	});
}

if (host !== 'localhost') {
	registerToLoadBalancer();
}

app.use(bodyParser.json());

function countFactorial(num) {
	let n = Number(num);
	let res = 1;
	for (let i = 2; i <= n; i++) {
		res *= i;
	}
	return res;
}

/*
Gets a random key from redis and then gets the value of that key.
*/
app.get('/random', (req, res) => {
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
