import pytest
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from app import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as c:
        yield c

def test_health(client):
    r = client.get('/health')
    assert r.status_code == 200
    data = r.get_json()
    assert data['status'] == 'healthy'

def test_get_items(client):
    r = client.get('/api/items')
    assert r.status_code == 200
    data = r.get_json()
    assert 'items' in data
    assert data['count'] > 0

def test_add_item(client):
    r = client.post('/api/items', json={"name": "Test from pytest"})
    assert r.status_code == 201
    assert r.get_json()['name'] == "Test from pytest"