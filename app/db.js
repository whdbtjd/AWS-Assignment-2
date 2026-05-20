'use strict';

/**
 * DB layer — Aurora MySQL (mysql2 pool).
 * Credentials: DB_SECRET_ARN + IAM (EC2) or DB_PASSWORD (local).
 */

const mysql = require('mysql2/promise');
const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');

let pool;

async function resolveCredentials() {
  const database = process.env.DB_NAME;
  const host = process.env.DB_HOST;

  if (!database || !host) {
    throw new Error('DB_HOST and DB_NAME are required');
  }

  if (process.env.DB_PASSWORD) {
    return {
      host,
      database,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
    };
  }

  const secretArn = process.env.DB_SECRET_ARN;
  if (!secretArn) {
    throw new Error('Set DB_SECRET_ARN (AWS) or DB_PASSWORD (local)');
  }

  const region = process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION || 'ap-northeast-2';
  const client = new SecretsManagerClient({ region });
  const { SecretString } = await client.send(
    new GetSecretValueCommand({ SecretId: secretArn }),
  );
  const secret = JSON.parse(SecretString);

  return {
    host,
    database,
    user: secret.username,
    password: secret.password,
  };
}

async function ensureSchema(connection) {
  await connection.query(`
    CREATE TABLE IF NOT EXISTS orders (
      order_id      VARCHAR(36)  NOT NULL PRIMARY KEY,
      product_id    VARCHAR(64)  NOT NULL,
      product_name  VARCHAR(255) NOT NULL,
      unit_price    DECIMAL(10,2) NOT NULL,
      quantity      INT          NOT NULL,
      total_price   DECIMAL(10,2) NOT NULL,
      created_at    DATETIME(3)  NOT NULL,
      INDEX idx_orders_created_at (created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  `);
}

async function init() {
  const maxAttempts = 12;
  let lastErr;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      const creds = await resolveCredentials();
      pool = mysql.createPool({
        host: creds.host,
        user: creds.user,
        password: creds.password,
        database: creds.database,
        waitForConnections: true,
        connectionLimit: Number(process.env.DB_POOL_SIZE || 10),
        queueLimit: 0,
        enableKeepAlive: true,
      });

      const conn = await pool.getConnection();
      try {
        await ensureSchema(conn);
      } finally {
        conn.release();
      }

      return;
    } catch (err) {
      lastErr = err;
      if (attempt < maxAttempts) {
        await new Promise((r) => setTimeout(r, 10_000));
      }
    }
  }

  throw lastErr;
}

async function saveOrder(orderData) {
  if (!pool) throw new Error('DB not initialized — call init() first');

  await pool.execute(
    `INSERT INTO orders
      (order_id, product_id, product_name, unit_price, quantity, total_price, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [
      orderData.orderId,
      orderData.productId,
      orderData.productName,
      orderData.unitPrice,
      orderData.quantity,
      orderData.totalPrice,
      new Date(orderData.createdAt),
    ],
  );

  return { orderId: orderData.orderId };
}

async function getOrders() {
  if (!pool) throw new Error('DB not initialized — call init() first');

  const [rows] = await pool.query(
    `SELECT order_id AS orderId, product_id AS productId, product_name AS productName,
            unit_price AS unitPrice, quantity, total_price AS totalPrice,
            created_at AS createdAt
     FROM orders
     ORDER BY created_at DESC`,
  );

  return rows.map((row) => ({
    ...row,
    createdAt: row.createdAt instanceof Date ? row.createdAt.toISOString() : row.createdAt,
  }));
}

module.exports = { init, saveOrder, getOrders };
