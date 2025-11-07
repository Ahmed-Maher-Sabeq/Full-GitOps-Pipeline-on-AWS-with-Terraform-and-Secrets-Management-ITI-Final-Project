const redis = require('redis');

// Redis configuration from environment variables
const redisConfig = {
  socket: {
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379,
    connectTimeout: 5000,
    reconnectStrategy: (retries) => {
      if (retries > 10) {
        console.error('❌ Redis: Too many reconnection attempts, giving up');
        return new Error('Too many retries');
      }
      const delay = Math.min(retries * 100, 3000);
      console.log(`⏳ Redis: Reconnecting in ${delay}ms (attempt ${retries})`);
      return delay;
    }
  }
};

// Create Redis client
const client = redis.createClient(redisConfig);

// Default TTL for cached items (5 minutes)
const DEFAULT_TTL = 300;

// Redis event handlers
client.on('connect', () => {
  console.log('🔄 Redis: Connecting...');
});

client.on('ready', () => {
  console.log('✅ Redis: Connected and ready');
});

client.on('error', (err) => {
  console.error('❌ Redis error:', err.message);
});

client.on('reconnecting', () => {
  console.log('🔄 Redis: Reconnecting...');
});

client.on('end', () => {
  console.log('⚠️  Redis: Connection closed');
});

// Connect to Redis
async function connectRedis() {
  try {
    await client.connect();
    return true;
  } catch (error) {
    console.error('❌ Failed to connect to Redis:', error.message);
    console.log('⚠️  Application will continue without caching');
    return false;
  }
}

// Check if Redis is connected
function isConnected() {
  return client.isOpen;
}

// Get value from cache
async function get(key) {
  if (!isConnected()) {
    return null;
  }
  try {
    const value = await client.get(key);
    return value ? JSON.parse(value) : null;
  } catch (error) {
    console.error(`❌ Redis GET error for key ${key}:`, error.message);
    return null;
  }
}

// Set value in cache with TTL
async function set(key, value, ttl = DEFAULT_TTL) {
  if (!isConnected()) {
    return false;
  }
  try {
    await client.setEx(key, ttl, JSON.stringify(value));
    return true;
  } catch (error) {
    console.error(`❌ Redis SET error for key ${key}:`, error.message);
    return false;
  }
}

// Delete key from cache
async function del(key) {
  if (!isConnected()) {
    return false;
  }
  try {
    await client.del(key);
    return true;
  } catch (error) {
    console.error(`❌ Redis DEL error for key ${key}:`, error.message);
    return false;
  }
}

// Graceful shutdown
async function disconnect() {
  if (isConnected()) {
    await client.quit();
    console.log('✅ Redis: Disconnected gracefully');
  }
}

module.exports = {
  connectRedis,
  isConnected,
  get,
  set,
  del,
  disconnect,
  DEFAULT_TTL
};
