/**
 * App.jsx -- root React component.
 *
 * Lays out a centered Bootstrap grid (Col md offset 3 / span 6 = half width,
 * centered) and composes the two feature components, Greeting and TodoListCard.
 * Holds no state of its own; each child manages its own data.
 */
import Col from 'react-bootstrap/Col';
import Container from 'react-bootstrap/Container';
import Row from 'react-bootstrap/Row';
import { TodoListCard } from './components/TodoListCard';
import { Greeting } from './components/Greeting';

function App() {
    return (
        <Container>
            <Row>
                <Col md={{ offset: 3, span: 6 }}>
                    <Greeting />
                    <TodoListCard />
                </Col>
            </Row>
        </Container>
    );
}

export default App;
