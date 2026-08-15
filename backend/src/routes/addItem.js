/**
 * POST /api/items handler.
 *
 * Builds a new item with a generated UUID, name from req.body.name (populated by
 * the express.json() middleware), and completed=false; stores it; returns it.
 * The client (AddNewItemForm.jsx) sends the name as JSON in the request body.
 */
const db = require('../persistence');
const { v4: uuid } = require('uuid');

module.exports = async (req, res) => {
    const item = {
        id: uuid(),
        name: req.body.name,
        completed: false,
    };

    await db.storeItem(item);
    res.send(item);
};
