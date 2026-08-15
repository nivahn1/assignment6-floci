/**
 * GET /api/greeting handler.
 *
 * Returns a static greeting object; does not touch the database. The response
 * key (greeting_from_backend) is the contract the client reads in Greeting.jsx
 * -- both sides must use the same name or the value arrives as undefined.
 */
const GREETING = 'Hello world!';

module.exports = async (req, res) => {
    res.send({
        greeting_from_backend: GREETING,
    });
};
