/*
This file is only for testing the connection.
Usage:

node index.js

OR with argument

node index.js <url>
*/
const axios = require('axios');

let url = process.argv[2] || 'http://localhost:8000/random';

console.log('Sending request to ' + url);

axios.get(url).then(res => {
	console.log('Response from server: ' + res.data);
}).catch(err => {
	console.log('Error: ' + err);
});
