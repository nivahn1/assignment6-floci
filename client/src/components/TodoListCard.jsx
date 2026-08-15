/**
 * TodoListCard.jsx -- the list container and state owner.
 *
 * Owns the `items` array (starts null to distinguish "loading" from "empty").
 * Loads items once on mount, then coordinates add/update/remove by passing
 * memoized callbacks (useCallback) down to AddItemForm and ItemDisplay --
 * the "lifting state up" pattern. All updates are immutable (spread/slice), so
 * React detects the change by reference and re-renders. Each row uses a stable
 * key={item.id}.
 */
import { useCallback, useEffect, useState } from 'react';
import { AddItemForm } from './AddNewItemForm';
import { ItemDisplay } from './ItemDisplay';

export function TodoListCard() {
    const [items, setItems] = useState(null);

    useEffect(() => {
        // GET is fetch's default method; stated explicitly here for clarity.
        fetch('/api/items', { method: 'GET' })
            .then((r) => r.json())
            .then(setItems);
    }, []);

    const onNewItem = useCallback(
        (newItem) => {
            setItems([...items, newItem]);
        },
        [items],
    );

    const onItemUpdate = useCallback(
        (item) => {
            const index = items.findIndex((i) => i.id === item.id);
            setItems([
                ...items.slice(0, index),
                item,
                ...items.slice(index + 1),
            ]);
        },
        [items],
    );

    const onItemRemoval = useCallback(
        (item) => {
            const index = items.findIndex((i) => i.id === item.id);
            setItems([...items.slice(0, index), ...items.slice(index + 1)]);
        },
        [items],
    );

    if (items === null) return 'Loading...';

    return (
        <>
            <AddItemForm onNewItem={onNewItem} />
            {items.length === 0 && (
                <p className="text-center">No items yet! Add one above!</p>
            )}
            {items.map((item) => (
                <ItemDisplay
                    key={item.id}
                    item={item}
                    onItemUpdate={onItemUpdate}
                    onItemRemoval={onItemRemoval}
                />
            ))}
        </>
    );
}
