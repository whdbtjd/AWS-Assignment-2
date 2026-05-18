'use strict';

const express = require('express');
const path    = require('path');
const { v4: uuidv4 } = require('uuid');
const db      = require('./db');

const app  = express();
const PORT = process.env.PORT || 3001;

// ── Structured JSON logger ────────────────────────────────────────────────────

function log(level, event, meta = {}) {
  console.log(JSON.stringify({
    timestamp: new Date().toISOString(),
    level,
    event,
    ...meta,
  }));
}

// ── Middleware ────────────────────────────────────────────────────────────────

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Request logger — emits one JSON line per incoming request
app.use((req, _res, next) => {
  log('INFO', 'http_request', {
    method: req.method,
    path:   req.path,
    query:  req.query,
    ip:     req.headers['x-forwarded-for'] || req.socket.remoteAddress,
    userAgent: req.headers['user-agent'],
  });
  next();
});

// ── Hardcoded product catalogue ───────────────────────────────────────────────

const PRODUCTS = [
  { id: 'prod-001', name: 'Wireless Keyboard',    price: 49.99 },
  { id: 'prod-002', name: 'Ergonomic Mouse',       price: 34.99 },
  { id: 'prod-003', name: 'USB-C Hub (7-in-1)',    price: 29.99 },
  { id: 'prod-004', name: '27" Monitor Stand',     price: 59.99 },
];

// ── Frontend entry point ──────────────────────────────────────────────────────

app.get('/', (_req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// ── API Routes ────────────────────────────────────────────────────────────────

/**
 * GET /api/products
 * Returns the hardcoded product catalogue.
 */
app.get('/api/products', (_req, res) => {
  log('INFO', 'db_read', { table: 'products', count: PRODUCTS.length });
  res.json(PRODUCTS);
});

/**
 * POST /api/orders
 * Body: { productId: string, quantity: number }
 * Validates input, persists order via the DB abstraction layer, returns orderId.
 */
app.post('/api/orders', async (req, res) => {
  const { productId, quantity } = req.body;

  // ── input validation
  if (!productId || !quantity || quantity < 1) {
    log('WARN', 'order_validation_failed', { productId, quantity });
    return res.status(400).json({ success: false, message: 'productId and quantity (≥1) are required.' });
  }

  const product = PRODUCTS.find(p => p.id === productId);
  if (!product) {
    log('WARN', 'order_product_not_found', { productId });
    return res.status(404).json({ success: false, message: `Product '${productId}' not found.` });
  }

  const orderData = {
    orderId:   uuidv4(),
    productId,
    productName: product.name,
    unitPrice:   product.price,
    quantity:    Number(quantity),
    totalPrice:  +(product.price * quantity).toFixed(2),
    createdAt:   new Date().toISOString(),
  };

  try {
    log('INFO', 'db_write_start', { table: 'orders', orderId: orderData.orderId });
    await db.saveOrder(orderData);
    log('INFO', 'db_write_success', { table: 'orders', orderId: orderData.orderId });

    res.status(201).json({ success: true, orderId: orderData.orderId, total: orderData.totalPrice });
  } catch (err) {
    log('ERROR', 'db_write_error', { error: err.message, stack: err.stack });
    res.status(500).json({ success: false, message: 'Internal server error.' });
  }
});

// ── 404 catch-all ─────────────────────────────────────────────────────────────

app.use((_req, res) => {
  res.status(404).json({ success: false, message: 'Route not found.' });
});

// ── Start ─────────────────────────────────────────────────────────────────────

app.listen(PORT, () => {
  log('INFO', 'server_start', { port: PORT, env: process.env.NODE_ENV || 'development' });
});

module.exports = app;
