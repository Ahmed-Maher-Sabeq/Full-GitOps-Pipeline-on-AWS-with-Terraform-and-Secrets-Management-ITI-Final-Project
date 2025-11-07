const express = require('express');
const router = express.Router();
const { isConnected: isMySQLConnected } = require('../config/database');
const { isConnected: isRedisConnected } = require('../config/redis');

// Health check endpoint
router.get('/health', async (req, res) => {
  try {
    const mysqlStatus = await isMySQLConnected();
    const redisStatus = isRedisConnected();
    
    const health = {
      status: mysqlStatus ? 'healthy' : 'unhealthy',
      timestamp: new Date().toISOString(),
      services: {
        mysql: mysqlStatus ? 'connected' : 'disconnected',
        redis: redisStatus ? 'connected' : 'disconnected'
      }
    };
    
    // Return 503 if MySQL is down (critical service)
    // Redis is optional, so we don't fail health check if it's down
    const statusCode = mysqlStatus ? 200 : 503;
    
    res.status(statusCode).json(health);
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: error.message
    });
  }
});

// Readiness check (same as health for now)
router.get('/ready', async (req, res) => {
  try {
    const mysqlStatus = await isMySQLConnected();
    
    if (mysqlStatus) {
      res.status(200).json({ status: 'ready' });
    } else {
      res.status(503).json({ status: 'not ready' });
    }
  } catch (error) {
    res.status(503).json({ status: 'not ready', error: error.message });
  }
});

// Liveness check (simple check that app is running)
router.get('/live', (req, res) => {
  res.status(200).json({ status: 'alive' });
});

module.exports = router;
