#!/bin/bash
set -euo pipefail
exec > /var/log/user-data.log 2>&1

# ── 1. 시스템 업데이트 ────────────────────────────────────────────────────────
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y git curl

# ── 2. Node.js 20 LTS 설치 ───────────────────────────────────────────────────
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# ── 3. PM2 설치 ──────────────────────────────────────────────────────────────
npm install -g pm2

# ── 4. 앱 소스 배치 ──────────────────────────────────────────────────────────
APP_DIR="/opt/app"
mkdir -p "$APP_DIR"

%{ if app_git_repo != "" ~}
git clone ${app_git_repo} "$APP_DIR"
cd "$APP_DIR/${app_subdir}"
%{ else ~}
mkdir -p "$APP_DIR/public"

cat > "$APP_DIR/package.json" << 'PKGJSON'
{
  "name": "acme-store",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": { "start": "node server.js" },
  "dependencies": {
    "@aws-sdk/client-secrets-manager": "^3.812.0",
    "express": "^4.18.2",
    "mysql2": "^3.14.1",
    "uuid": "^9.0.0"
  }
}
PKGJSON

cat > "$APP_DIR/db.js" << 'DBJS'
'use strict';
const fs   = require('fs');
const path = require('path');
const DB_FILE = path.join(__dirname, 'orders.json');
function _readAll() {
  if (!fs.existsSync(DB_FILE)) return [];
  try { return JSON.parse(fs.readFileSync(DB_FILE, 'utf8')); } catch { return []; }
}
function _writeAll(orders) { fs.writeFileSync(DB_FILE, JSON.stringify(orders, null, 2), 'utf8'); }
async function saveOrder(orderData) { const o = _readAll(); o.push(orderData); _writeAll(o); return { orderId: orderData.orderId }; }
async function getOrders() { return _readAll(); }
module.exports = { saveOrder, getOrders };
DBJS

cat > "$APP_DIR/server.js" << 'SERVERJS'
'use strict';
const express = require('express');
const path    = require('path');
const { v4: uuidv4 } = require('uuid');
const db      = require('./db');
const app     = express();
const PORT    = process.env.PORT || 3001;

function log(level, event, meta = {}) {
  console.log(JSON.stringify({ timestamp: new Date().toISOString(), level, event, ...meta }));
}

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

app.use((req, _res, next) => {
  log('INFO', 'http_request', { method: req.method, path: req.path, ip: req.headers['x-forwarded-for'] || req.socket.remoteAddress });
  next();
});

const PRODUCTS = [
  { id: 'prod-001', name: 'Wireless Keyboard', price: 49.99 },
  { id: 'prod-002', name: 'Ergonomic Mouse',    price: 34.99 },
  { id: 'prod-003', name: 'USB-C Hub (7-in-1)', price: 29.99 },
  { id: 'prod-004', name: '27" Monitor Stand',  price: 59.99 },
];

app.get('/',             (_req, res) => res.sendFile(path.join(__dirname, 'public', 'index.html')));
app.get('/api/products', (_req, res) => { log('INFO','db_read',{table:'products'}); res.json(PRODUCTS); });
app.post('/api/orders', async (req, res) => {
  const { productId, quantity } = req.body;
  const product = PRODUCTS.find(p => p.id === productId);
  if (!product) return res.status(404).json({ success: false, message: 'Product not found.' });
  const orderData = { orderId: uuidv4(), productId, productName: product.name, quantity: Number(quantity), totalPrice: +(product.price * quantity).toFixed(2), createdAt: new Date().toISOString() };
  await db.saveOrder(orderData);
  log('INFO', 'order_created', { orderId: orderData.orderId });
  res.status(201).json({ success: true, orderId: orderData.orderId, total: orderData.totalPrice });
});
app.use((_req, res) => res.status(404).json({ success: false, message: 'Route not found.' }));
app.listen(PORT, () => log('INFO', 'server_start', { port: PORT }));
SERVERJS

cat > "$APP_DIR/public/index.html" << 'INDEXHTML'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>ACME Store</title></head>
<body><h1>ACME Store</h1><div id="products"></div>
<script>
fetch('/api/products').then(r=>r.json()).then(products=>{
  document.getElementById('products').innerHTML = products.map(p=>
    '<div><b>' + p.name + '</b> $' + p.price +
    ' <button onclick="buy(\'' + p.id + '\')">Buy Now</button></div>'
  ).join('');
});
function buy(id){
  fetch('/api/orders',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({productId:id,quantity:1})})
    .then(r=>r.json()).then(d=>alert('Order: '+d.orderId));
}
</script></body></html>
INDEXHTML

cd "$APP_DIR"
%{ endif ~}

# ── 5. Aurora 연결 환경 변수 ─────────────────────────────────────────────────
export DB_HOST="${db_host}"
export DB_NAME="${db_name}"
export DB_USER="${db_user}"
export DB_SECRET_ARN="${db_secret_arn}"
export AWS_REGION="${aws_region}"
export PORT="${app_port}"

# ── 6. 의존성 설치 ────────────────────────────────────────────────────────────
npm install --omit=dev

# ── 7. PM2로 앱 시작 & 재부팅 시 자동 실행 ───────────────────────────────────
pm2 delete acme-store 2>/dev/null || true
pm2 start server.js --name acme-store --update-env
pm2 startup systemd -u root --hp /root
pm2 save

echo "Deployment complete — port ${app_port} (Aurora ${db_host})"
