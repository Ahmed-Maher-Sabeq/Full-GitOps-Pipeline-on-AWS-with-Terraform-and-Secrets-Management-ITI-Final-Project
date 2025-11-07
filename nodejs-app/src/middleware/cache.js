const redis = require('../config/redis');

// Cache middleware for GET requests
function cacheMiddleware(keyGenerator) {
  return async (req, res, next) => {
    // Only cache GET requests
    if (req.method !== 'GET') {
      return next();
    }
    
    try {
      // Generate cache key
      const cacheKey = typeof keyGenerator === 'function' 
        ? keyGenerator(req) 
        : keyGenerator;
      
      // Try to get from cache
      const cachedData = await redis.get(cacheKey);
      
      if (cachedData) {
        console.log(`✅ Cache HIT for key: ${cacheKey}`);
        return res.json({
          ...cachedData,
          cached: true
        });
      }
      
      console.log(`❌ Cache MISS for key: ${cacheKey}`);
      
      // Store original json method
      const originalJson = res.json.bind(res);
      
      // Override json method to cache the response
      res.json = function(data) {
        // Cache the response data
        redis.set(cacheKey, data).catch(err => {
          console.error(`Failed to cache data for key ${cacheKey}:`, err.message);
        });
        
        // Add cached flag and send response
        return originalJson({
          ...data,
          cached: false
        });
      };
      
      next();
    } catch (error) {
      console.error('Cache middleware error:', error.message);
      next();
    }
  };
}

// Invalidate cache for specific key
async function invalidateCache(key) {
  try {
    await redis.del(key);
    console.log(`🗑️  Cache invalidated for key: ${key}`);
    return true;
  } catch (error) {
    console.error(`Failed to invalidate cache for key ${key}:`, error.message);
    return false;
  }
}

// Invalidate multiple cache keys
async function invalidateMultiple(keys) {
  const promises = keys.map(key => invalidateCache(key));
  await Promise.all(promises);
}

module.exports = {
  cacheMiddleware,
  invalidateCache,
  invalidateMultiple
};
