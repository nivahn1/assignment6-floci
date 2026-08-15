/**
 * GET /api/items handler.
 *
 * Reads every todo item from the persistence layer and sends the array back.
 * db is the shared data-access module (MySQL or SQLite, chosen at startup).
 */
const db = require('../persistence');

module.exports = async (req, res) => {
    const items = await db.getItems();
    res.send(items);
};
