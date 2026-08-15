# Getting Started Todo App — Study Notes

These notes summarize a walkthrough of how the todo app's frontend (React/Vite
client) and backend (Node.js/Express API) are structured and how they
communicate. They were compiled while studying the codebase file by file.

## 1. Architecture overview

The app runs as a set of Docker Compose services (see `compose.yaml`):

- **proxy** (Traefik) — reverse proxy. Routes `localhost/api/*` to the backend
  and everything else to the client. This is why the client can use relative
  `/api/*` URLs and stay unaware of the backend's host/port.
- **client** — React app served by Vite (dev) on port 5173.
- **backend** — Express API on port 3000.
- **mysql** — database (chosen at runtime when `MYSQL_HOST` is set).
- **phpmyadmin** — web UI for the database at `db.localhost`.

Data flow between components:

```
Greeting.jsx      --GET  /api/greeting-->  getGreeting.js
TodoListCard.jsx  --GET  /api/items----->  getItems.js
AddNewItemForm    --POST /api/items----->  addItem.js
ItemDisplay.jsx   --PUT  /api/items/:id->  updateItem.js
ItemDisplay.jsx   --DELETE /api/items/:id> deleteItem.js
```

State lives in `TodoListCard` (the container); child components communicate
upward via callback props ("lifting state up"). Every state update is
immutable (spread operators build new arrays/objects) so React re-renders.

## 2. Backend

### `backend/src/index.js` (lines 1–17)
- Lines 1–2: `require('express')` (CommonJS import) then `express()` creates the
  `app` instance — the core Express idiom.
- Line 3: `require('./persistence')` imports a **directory**, so Node resolves it
  to `persistence/index.js` (directory import → `index.js` fallback).
- Lines 4–8: `require('./routes/...')` import individual handler **files** (Node
  auto-appends `.js`). Each route file exports one `(req, res)` function.
- Line 10: `express.json()` middleware parses JSON bodies into `req.body`.
- Line 11: `express.static(...)` serves the built frontend from `/static`.
- Lines 13–17: bind HTTP method + path to a handler. Routing key is
  **method + path**, so `GET /api/items` and `POST /api/items` are distinct
  routes sharing a URL. `:id` is a route parameter exposed as `req.params.id`.
- The server only starts listening after `db.init()` succeeds.

### Route handlers
- `getGreeting.js` — returns a static greeting object. No DB.
- `getItems.js` — reads all items from the DB and sends them.
- `addItem.js` — generates a UUID, stores a new item, returns it.
- `updateItem.js` — updates name/completed by `:id`, returns the updated item.
- `deleteItem.js` — removes the item by `:id`, responds with status 200.

### Module resolution recap
- `require('./persistence')` → directory → loads `persistence/index.js`.
- `require('./routes/getItems')` → file → loads `getItems.js` (extension inferred).

## 3. Frontend

### `App.jsx`
Root component. Lays out a centered Bootstrap grid and composes `Greeting` and
`TodoListCard`. Holds no state itself.

### `components/Greeting.jsx`
- `const [greeting, setGreeting] = useState(null)` — array destructuring of the
  `[value, setter]` tuple React returns. `setGreeting` is created/defined by
  React; calling it stores a value and triggers a re-render.
- `useEffect(fn, [])` runs the fetch once on mount.
- **Promise chain:** `fetch(...)` resolves to a `Response` (`res`); `res.json()`
  returns another Promise resolving to the parsed body (`data`); the parsed
  value is stored via `setGreeting`. `.then()` returns a new Promise each time,
  which is what allows chaining.
- Guard clause `if (!greeting) return null;` renders nothing while loading.

### `components/TodoListCard.jsx`
- Owns the `items` array (starts `null` to distinguish "loading" from "empty").
- `useEffect(..., [])` loads items once on mount (method made explicit as GET
  for readability; GET is fetch's default).
- `useCallback(fn, [items])` memoizes the add/update/remove handlers so their
  references stay stable across renders (they're passed as props).
- Immutable updates via spread/slice. Renders `AddItemForm` and one
  `ItemDisplay` per item, with a stable `key={item.id}`.

### `components/AddNewItemForm.jsx`
- Controlled input: `value={newItem}` + `onChange` bind the field to state.
- `submitNewItem` calls `e.preventDefault()`, then POSTs `{ name }` as JSON.
- On success it lifts the new item to the parent via `onNewItem`, then resets.
- `submitting` state toggles the button label / disabled state.

### `components/ItemDisplay.jsx`
- Renders a single row with a toggle-complete button and a delete button.
- `toggleCompletion` sends `PUT /api/items/:id` with the flipped `completed`.
- `removeItem` sends `DELETE /api/items/:id` (no body, no JSON parse — backend
  replies with just status 200).
- Template literals interpolate `item.id` into the URL to match the `:id` route.

## 4. HTTP method notes
- `fetch` defaults to **GET** when no method is given. `POST`, `PUT`, and
  `DELETE` must be stated explicitly because they deviate from the default and
  (for POST/PUT) carry a body.
- The backend distinguishes methods on the same path because Express routes on
  **method + path** together.

## 5. Contract between services
- The client and backend must agree on JSON property names. Example: renaming
  the greeting key to `greeting_from_backend` is safe **only** because it was
  changed in both `getGreeting.js` (sender) and `Greeting.jsx` (reader). Change
  one side only and the value arrives as `undefined`.
- Route paths (`/api/...`) and route parameters (`:id`) must also match on both
  ends.
