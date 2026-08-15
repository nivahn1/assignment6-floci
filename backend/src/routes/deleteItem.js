/**
 * DELETE /api/items/:id handler.
 *
 * Removes the item identified by req.params.id and replies with just status 200
 * (no body). ItemDisplay.jsx therefore doesn't parse JSON on the response.
 */
const db = require('../persistence');

module.exports = async (req, res) => {
    await db.removeItem(req.params.id);
    res.sendStatus(200);
};
