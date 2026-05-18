'use strict';

/**
 * DB Abstraction Layer
 *
 * Current driver: local filesystem (orders.json)
 * To swap to a real DB (e.g. AWS RDS MySQL, DynamoDB), replace ONLY the
 * internals of each exported function — the contract (function signatures
 * and return shapes) must stay the same.
 *
 * Contract:
 *   saveOrder(orderData: Object) -> Promise<{ orderId: string }>
 *   getOrders()                  -> Promise<Array>
 */

const fs   = require('fs');
const path = require('path');

const DB_FILE = path.join(__dirname, 'orders.json');

// ── helpers ──────────────────────────────────────────────────────────────────

function _readAll() {
  if (!fs.existsSync(DB_FILE)) return [];
  try {
    return JSON.parse(fs.readFileSync(DB_FILE, 'utf8'));
  } catch {
    return [];
  }
}

function _writeAll(orders) {
  fs.writeFileSync(DB_FILE, JSON.stringify(orders, null, 2), 'utf8');
}

// ── public API ────────────────────────────────────────────────────────────────

/**
 * Persist a new order.
 * @param {Object} orderData  - { orderId, productId, quantity, createdAt, ... }
 * @returns {Promise<{ orderId: string }>}
 */
async function saveOrder(orderData) {
  const orders = _readAll();
  orders.push(orderData);
  _writeAll(orders);
  return { orderId: orderData.orderId };
}

/**
 * Retrieve all persisted orders.
 * @returns {Promise<Array>}
 */
async function getOrders() {
  return _readAll();
}

module.exports = { saveOrder, getOrders };
