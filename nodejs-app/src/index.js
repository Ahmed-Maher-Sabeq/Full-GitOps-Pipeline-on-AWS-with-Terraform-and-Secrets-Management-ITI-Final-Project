const express = require('express');
const path = require('path');
const { testConnection } = require('./config/database');
const { connectRedis, disconnect: disconnectRedis } = require('./config/redis');
const { initializeDatabase } = require('./config/init-db');
const healthRoutes = require('./routes/health');
const apiRoutes = require('./routes/api');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Serve static files from public directory
app.use(express.static(path.join(__dirname, '../public')));

// Request logging middleware
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(`${req.method} ${req.path} ${res.statusCode} - ${duration}ms`);
  });
  next();
});

// Routes
app.use('/', healthRoutes);
app.use('/api', apiRoutes);

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: `Cannot ${req.method} ${req.path}`
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({
    error: 'Internal Server Error',
    message: err.message
  });
});

// Graceful shutdown
async function gracefulShutdown(signal) {
  console.log(`\n${signal} received, shutting down gracefully...`);
  
  server.close(async () => {
    console.log('✅ HTTP server closed');
    
    // Disconnect from Redis
    await disconnectRedis();
    
    console.log('✅ All connections closed');
    process.exit(0);
  });
  
  // Force shutdown after 10 seconds
  setTimeout(() => {
    console.error('⚠️  Forced shutdown after timeout');
    process.exit(1);
  }, 10000);
}

// Initialize and start server
let server;

async function startServer() {
  try {
    console.log('🚀 Starting Node.js GitOps Application...');
    console.log('📋 Environment:', {
      NODE_ENV: process.env.NODE_ENV || 'development',
      PORT: PORT,
      DB_HOST: process.env.DB_HOST || 'localhost',
      DB_NAME: process.env.DB_NAME || 'appdb',
      REDIS_HOST: process.env.REDIS_HOST || 'localhost'
    });
    
    // Connect to MySQL
    console.log('\n📊 Connecting to MySQL...');
    const mysqlConnected = await testConnection();
    if (!mysqlConnected) {
      throw new Error('Failed to connect to MySQL database');
    }
    
    // Initialize database schema
    await initializeDatabase();
    
    // Connect to Redis (non-blocking)
    console.log('\n🔴 Connecting to Redis...');
    await connectRedis();
    
    // Start HTTP server
    server = app.listen(PORT, () => {
      console.log(`\n✅ Server is running on port ${PORT}`);
      console.log(`🌐 Health check: http://localhost:${PORT}/health`);
      console.log(`📡 API endpoint: http://localhost:${PORT}/api/items`);
      console.log('\n✨ Application started successfully!\n');
    });
    
    // Handle graceful shutdown
    process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
    process.on('SIGINT', () => gracefulShutdown('SIGINT'));
    
  } catch (error) {
    console.error('❌ Failed to start server:', error.message);
    process.exit(1);
  }
}

// Start the server
startServer();
