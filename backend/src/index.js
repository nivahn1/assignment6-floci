/**
 * Backend entry point (Express API server).
 *
 * - require('express') is a CommonJS import; express() creates the `app`.
 * - require('./persistence') imports a DIRECTORY, so Node resolves it to
 *   persistence/index.js (directory import -> index.js fallback). That module
 *   picks MySQL or SQLite based on the MYSQL_HOST env var.
 * - The route requires below import individual FILES (Node auto-appends .js);
 *   each exports one (req, res) handler.
 * - express.json() parses JSON request bodies into req.body.
 * - express.static() serves the built frontend from /static.
 * - Routes bind an HTTP method + path to a handler. Express routes on
 *   method + path together, so GET and POST on /api/items are distinct routes.
 *   `:id` is a route parameter, available as req.params.id.
 * - The server only starts listening after db.init() succeeds.
 */
const express = require('express');
const app = express();
const db = require('./persistence');
const getGreeting = require('./routes/getGreeting');
const getItems = require('./routes/getItems');
const addItem = require('./routes/addItem');
const updateItem = require('./routes/updateItem');
const deleteItem = require('./routes/deleteItem');

app.use(express.json());
app.use(express.static(__dirname + '/static'));

app.get('/api/greeting', getGreeting);
app.get('/api/items', getItems);
app.post('/api/items', addItem);
app.put('/api/items/:id', updateItem);
app.delete('/api/items/:id', deleteItem);

db.init()
    .then(() => {
        app.listen(3000, () => console.log('Listening on port 3000'));
    })
    .catch((err) => {
        console.error(err);
        process.exit(1);
    });

const gracefulShutdown = () => {
    db.teardown()
        .catch(() => {})
        .then(() => process.exit());
};

process.on('SIGINT', gracefulShutdown);
process.on('SIGTERM', gracefulShutdown);
process.on('SIGUSR2', gracefulShutdown); // Sent by nodemon
