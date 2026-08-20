# Component & Route Hierarchy

## Client Component Tree

```
App (root)
├── Greeting
│   └── calls: GET /api/greeting
│
└── TodoListCard (state owner)
    ├── AddItemForm
    │   └── calls: POST /api/items
    │
    └── ItemDisplay (mapped, one per item)
        └── calls: PUT /api/items/:id, DELETE /api/items/:id
```

## Backend REST API Routes

**HTTP Methods:**
- **GET** — retrieve data (no side effects; safe to call multiple times)
- **POST** — create a new resource
- **PUT** — update an existing resource
- **DELETE** — remove a resource

| Method | Path | Handler | Called by |
|--------|------|---------|-----------|
| **GET** | `/api/greeting` | `getGreeting.js` | Greeting component (on mount) |
| **GET** | `/api/items` | `getItems.js` | TodoListCard (on mount) |
| **POST** | `/api/items` | `addItem.js` | AddItemForm (when user submits new item) |
| **PUT** | `/api/items/:id` | `updateItem.js` | ItemDisplay (when user updates an item) |
| **DELETE** | `/api/items/:id` | `deleteItem.js` | ItemDisplay (when user deletes an item) |

## Component State & Data Flow

**App** (stateless, layout only)
- Renders two independent feature components

**Greeting** (stateful)
- Fetches greeting message on mount
- Renders a simple welcome message

**TodoListCard** (stateful, owns the items array)
- Fetches all items on mount (`GET /api/items`)
- Passes memoized callbacks to children:
  - `onNewItem(newItem)` → AddItemForm
  - `onItemUpdate(item)` → ItemDisplay
  - `onItemRemoval(item)` → ItemDisplay
- Re-renders ItemDisplay when items change

**AddItemForm** (presentational)
- Receives `onNewItem` callback from TodoListCard
- On submit: calls `POST /api/items`, then calls `onNewItem()` with the response
- Parent (TodoListCard) updates its state

**ItemDisplay** (presentational, rendered once per item)
- Receives `item`, `onItemUpdate`, and `onItemRemoval` callbacks
- On update button: calls `PUT /api/items/:id`, then calls `onItemUpdate()` with response
- On delete button: calls `DELETE /api/items/:id`, then calls `onItemRemoval()` with the item
- Parent (TodoListCard) updates its state
