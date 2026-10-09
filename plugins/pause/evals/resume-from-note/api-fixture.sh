#!/usr/bin/env bash
# Builds ./api: a node orders API with one unpushed commit and a half-written POST /orders.
set -euo pipefail
g(){ git -c user.name=Test -c user.email=test@example.com "$@"; }
git init -q --bare remote.git
git clone -q remote.git api 2>/dev/null; cd api; git checkout -qb main
mkdir -p src/routes
echo '{ "name": "orders-api", "scripts": { "dev": "node src/server.js", "test": "node --test" } }' > package.json
cat > src/server.js <<'J'
const http = require('http');
const { listOrders } = require('./routes/orders');
http.createServer((req, res) => {
  if (req.url === '/orders') return listOrders(req, res);
  res.statusCode = 404; res.end();
}).listen(process.env.PORT || 3000);
J
cat > src/routes/orders.js <<'J'
const orders = [{ id: 1, total: 40 }];
exports.listOrders = (req, res) => { res.end(JSON.stringify(orders)); };
J
g add -A; g commit -qm "feat: orders list endpoint"; g push -q origin HEAD:main 2>/dev/null; g branch -q -u origin/main
echo "exports.isPositiveNumber = (n) => typeof n === 'number' && n > 0;" > src/routes/validate.js
g add -A; g commit -qm "feat: add validation helpers"
cat >> src/routes/orders.js <<'J'

const { isPositiveNumber } = require('./validate');
exports.createOrder = (req, res) => {
  let body = '';
  req.on('data', (c) => (body += c));
  req.on('end', () => {
    const payload = JSON.parse(body);
    if (!isPositiveNumber(payload.total)) { res.statusCode = 400; return res.end('invalid total'); }
    // TODO: assign id, push to orders, return 201
  });
};
J
sed -i "s#const { listOrders } = require('./routes/orders');#const { listOrders, createOrder } = require('./routes/orders');#" src/server.js
sed -i "s#if (req.url === '/orders') return listOrders(req, res);#if (req.url === '/orders' \&\& req.method === 'GET') return listOrders(req, res);\n  if (req.url === '/orders' \&\& req.method === 'POST') return createOrder(req, res);#" src/server.js
