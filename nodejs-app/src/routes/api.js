const express = require('express');
const router = express.Router();
const { pool } = require('../config/database');
const { cacheMiddleware, invalidateCache } = require('../middleware/cache');

// GET /api/items - List all items (with caching)
router.get('/items', cacheMiddleware('items:all'), async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT id, name, description, created_at, updated_at FROM items ORDER BY created_at DESC'
    );
    
    res.json({
      items: rows,
      count: rows.length
    });
  } catch (error) {
    console.error('Error fetching items:', error);
    res.status(500).json({
      error: 'Failed to fetch items',
      message: error.message
    });
  }
});

// GET /api/items/:id - Get single item by ID (with caching)
router.get('/items/:id', cacheMiddleware((req) => `item:${req.params.id}`), async (req, res) => {
  try {
    const { id } = req.params;
    
    // Validate ID
    if (!id || isNaN(id)) {
      return res.status(400).json({
        error: 'Invalid item ID'
      });
    }
    
    const [rows] = await pool.query(
      'SELECT id, name, description, created_at, updated_at FROM items WHERE id = ?',
      [id]
    );
    
    if (rows.length === 0) {
      return res.status(404).json({
        error: 'Item not found'
      });
    }
    
    res.json(rows[0]);
  } catch (error) {
    console.error('Error fetching item:', error);
    res.status(500).json({
      error: 'Failed to fetch item',
      message: error.message
    });
  }
});

// POST /api/items - Create new item
router.post('/items', async (req, res) => {
  try {
    const { name, description } = req.body;
    
    // Validate input
    if (!name || name.trim() === '') {
      return res.status(400).json({
        error: 'Item name is required'
      });
    }
    
    if (name.length > 255) {
      return res.status(400).json({
        error: 'Item name must be less than 255 characters'
      });
    }
    
    // Insert item
    const [result] = await pool.query(
      'INSERT INTO items (name, description) VALUES (?, ?)',
      [name.trim(), description || null]
    );
    
    // Get the created item
    const [rows] = await pool.query(
      'SELECT id, name, description, created_at, updated_at FROM items WHERE id = ?',
      [result.insertId]
    );
    
    // Invalidate cache
    await invalidateCache('items:all');
    
    res.status(201).json(rows[0]);
  } catch (error) {
    console.error('Error creating item:', error);
    res.status(500).json({
      error: 'Failed to create item',
      message: error.message
    });
  }
});

// PUT /api/items/:id - Update item
router.put('/items/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { name, description } = req.body;
    
    // Validate ID
    if (!id || isNaN(id)) {
      return res.status(400).json({
        error: 'Invalid item ID'
      });
    }
    
    // Validate input
    if (!name || name.trim() === '') {
      return res.status(400).json({
        error: 'Item name is required'
      });
    }
    
    if (name.length > 255) {
      return res.status(400).json({
        error: 'Item name must be less than 255 characters'
      });
    }
    
    // Update item
    const [result] = await pool.query(
      'UPDATE items SET name = ?, description = ? WHERE id = ?',
      [name.trim(), description || null, id]
    );
    
    if (result.affectedRows === 0) {
      return res.status(404).json({
        error: 'Item not found'
      });
    }
    
    // Get the updated item
    const [rows] = await pool.query(
      'SELECT id, name, description, created_at, updated_at FROM items WHERE id = ?',
      [id]
    );
    
    // Invalidate cache
    await invalidateCache(`item:${id}`);
    await invalidateCache('items:all');
    
    res.json(rows[0]);
  } catch (error) {
    console.error('Error updating item:', error);
    res.status(500).json({
      error: 'Failed to update item',
      message: error.message
    });
  }
});

// DELETE /api/items/:id - Delete item
router.delete('/items/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    // Validate ID
    if (!id || isNaN(id)) {
      return res.status(400).json({
        error: 'Invalid item ID'
      });
    }
    
    // Delete item
    const [result] = await pool.query('DELETE FROM items WHERE id = ?', [id]);
    
    if (result.affectedRows === 0) {
      return res.status(404).json({
        error: 'Item not found'
      });
    }
    
    // Invalidate cache
    await invalidateCache(`item:${id}`);
    await invalidateCache('items:all');
    
    res.json({
      message: 'Item deleted successfully',
      id: parseInt(id)
    });
  } catch (error) {
    console.error('Error deleting item:', error);
    res.status(500).json({
      error: 'Failed to delete item',
      message: error.message
    });
  }
});

module.exports = router;
