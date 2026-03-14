from flask import Flask, jsonify, request
import os, time, socket

app = Flask(__name__)

items = [
    {"id": 1, "name": "Build pipeline", "done": True},
    {"id": 2, "name": "Run tests", "done": False},
    {"id": 3, "name": "Deploy to ECS", "done": False},
]

@app.route('/health')
def health():
    return jsonify({"status": "healthy", "version": os.getenv("APP_VERSION", "1.0.0"), "host": socket.gethostname(), "timestamp": int(time.time())}), 200

@app.route('/api/items')
def get_items():
    return jsonify({"items": items, "count": len(items), "env": os.getenv("ENVIRONMENT", "dev")})

@app.route('/api/items', methods=['POST'])
def add_item():
    data = request.get_json()
    item = {"id": len(items)+1, "name": data.get("name", "Untitled"), "done": False}
    items.append(item)
    return jsonify(item), 201

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=False)