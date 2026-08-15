/**
 * PUT /api/items/:id handler.
 *
 * Updates the named/completed fields for the item identified by req.params.id
 * (the :id route parameter), then reads it back and returns the updated item.
 * Called by ItemDisplay.jsx when the user toggles an item's completion.
 */
const db = require('../persistence');

module.exports = async (req, res) => {
    await db.updateItem(req.params.id, {
        name: req.body.name,
        completed: req.body.completed,
    });
    const item = await db.getItem(req.params.id);
    res.send(item);
};
