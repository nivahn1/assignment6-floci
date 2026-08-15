/**
 * Greeting.jsx -- fetches and displays a greeting from the backend.
 *
 * - useState(null) returns [value, setter]; setGreeting is created by React and,
 *   when called, stores a value and triggers a re-render.
 * - useEffect(fn, []) runs the fetch once on mount.
 * - Promise chain: fetch() resolves to a Response (response); response.json()
 *   resolves to the parsed body (data_in_response); we read greeting_from_backend
 *   -- the key must match what getGreeting.js sends.
 * - Guard clause `if (!greeting) return null` renders nothing while loading.
 */
import { useEffect, useState } from 'react';

export function Greeting() {
    const [greeting, setGreeting] = useState(null);

    useEffect(() => {
        fetch('/api/greeting')
            .then((response) => response.json())
            .then((data_in_response) => setGreeting(data_in_response.greeting_from_backend));
    }, []);

    if (!greeting) return null;

    return <h1 className="text-center mb-5">{greeting}</h1>;
}
