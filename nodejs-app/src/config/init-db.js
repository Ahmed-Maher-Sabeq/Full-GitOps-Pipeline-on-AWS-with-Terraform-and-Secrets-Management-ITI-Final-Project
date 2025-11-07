const { pool } = require('./database');

// SQL to create items table
const createTableSQL = `
  CREATE TABLE IF NOT EXISTS items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_name (name)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
`;

// Initialize database schema
async function initializeDatabase() {
  try {
    console.log('🔧 Initializing database schema...');
    
    // Create items table
    await pool.query(createTableSQL);
    console.log('✅ Database schema initialized successfully');
    
    // Check if table has data
    const [rows] = await pool.query('SELECT COUNT(*) as count FROM items');
    const count = rows[0].count;
    
    if (count === 0) {
      console.log('📝 Items table is empty, inserting sample data...');
      await insertSampleData();
    } else {
      console.log(`📊 Items table has ${count} existing records`);
    }
    
    return true;
  } catch (error) {
    console.error('❌ Failed to initialize database:', error.message);
    throw error;
  }
}

// Insert sample data for testing
async function insertSampleData() {
  const sampleItems = [
    { name: 'Sample Item 1', description: 'This is a sample item for testing' },
    { name: 'Sample Item 2', description: 'Another sample item with description' },
    { name: 'Sample Item 3', description: 'Third sample item for demonstration' }
  ];
  
  try {
    for (const item of sampleItems) {
      await pool.query(
        'INSERT INTO items (name, description) VALUES (?, ?)',
        [item.name, item.description]
      );
    }
    console.log(`✅ Inserted ${sampleItems.length} sample items`);
  } catch (error) {
    console.error('❌ Failed to insert sample data:', error.message);
  }
}

module.exports = {
  initializeDatabase
};
