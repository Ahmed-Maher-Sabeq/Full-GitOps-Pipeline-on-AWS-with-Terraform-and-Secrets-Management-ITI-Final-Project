// API Base URL
const API_BASE = '/api';

// State
let tasks = [];
let editingTaskId = null;

// Initialize app
document.addEventListener('DOMContentLoaded', () => {
    loadHealth();
    loadTasks();
    setupEventListeners();
    
    // Refresh health status every 30 seconds
    setInterval(loadHealth, 30000);
});

// Setup event listeners
function setupEventListeners() {
    const form = document.getElementById('addTaskForm');
    form.addEventListener('submit', handleAddTask);
}

// Load health status
async function loadHealth() {
    try {
        const response = await fetch('/health');
        const health = await response.json();
        
        updateHealthStatus(health);
    } catch (error) {
        console.error('Failed to load health:', error);
        updateHealthStatus({ status: 'error', services: {} });
    }
}

// Update health status in UI
function updateHealthStatus(health) {
    const statusBadges = document.getElementById('statusBadges');
    const mysqlStatus = document.getElementById('mysqlStatus');
    const redisStatus = document.getElementById('redisStatus');
    const appVersion = document.getElementById('appVersion');
    
    // Update status badge
    const isHealthy = health.status === 'healthy';
    statusBadges.innerHTML = `
        <span class="badge ${isHealthy ? 'badge-success' : 'badge-danger'}">
            ${isHealthy ? '✓' : '✗'} ${isHealthy ? 'Healthy' : 'Unhealthy'}
        </span>
    `;
    
    // Update service statuses
    mysqlStatus.textContent = health.services?.mysql === 'connected' ? '✓ Connected' : '✗ Disconnected';
    mysqlStatus.style.color = health.services?.mysql === 'connected' ? 'var(--success)' : 'var(--danger)';
    
    redisStatus.textContent = health.services?.redis === 'connected' ? '✓ Connected' : '✗ Disconnected';
    redisStatus.style.color = health.services?.redis === 'connected' ? 'var(--success)' : 'var(--danger)';
    
    appVersion.textContent = health.version || 'Unknown';
}

// Load tasks
async function loadTasks() {
    const tasksList = document.getElementById('tasksList');
    tasksList.innerHTML = '<div class="loading">Loading tasks...</div>';
    
    try {
        const response = await fetch(`${API_BASE}/items`);
        const data = await response.json();
        
        tasks = data.items || [];
        renderTasks();
        updateTaskCount();
    } catch (error) {
        console.error('Failed to load tasks:', error);
        tasksList.innerHTML = `
            <div class="empty-state">
                <div class="empty-state-icon">⚠️</div>
                <p>Failed to load tasks. Please try again.</p>
            </div>
        `;
        showToast('Failed to load tasks', 'error');
    }
}

// Render tasks
function renderTasks() {
    const tasksList = document.getElementById('tasksList');
    
    if (tasks.length === 0) {
        tasksList.innerHTML = `
            <div class="empty-state">
                <div class="empty-state-icon">📝</div>
                <p>No tasks yet. Add your first task above!</p>
            </div>
        `;
        return;
    }
    
    tasksList.innerHTML = tasks.map(task => `
        <div class="task-item" id="task-${task.id}">
            ${editingTaskId === task.id ? renderEditForm(task) : renderTaskView(task)}
        </div>
    `).join('');
}

// Render task view
function renderTaskView(task) {
    const createdDate = new Date(task.created_at).toLocaleDateString();
    const updatedDate = task.updated_at ? new Date(task.updated_at).toLocaleDateString() : null;
    
    return `
        <div class="task-header">
            <div class="task-title">${escapeHtml(task.name)}</div>
            <div class="task-actions">
                <button class="btn btn-edit" onclick="startEdit(${task.id})">
                    ✏️ Edit
                </button>
                <button class="btn btn-danger" onclick="deleteTask(${task.id})">
                    🗑️ Delete
                </button>
            </div>
        </div>
        ${task.description ? `<div class="task-description">${escapeHtml(task.description)}</div>` : ''}
        <div class="task-meta">
            <span>📅 Created: ${createdDate}</span>
            ${updatedDate ? `<span>🔄 Updated: ${updatedDate}</span>` : ''}
        </div>
    `;
}

// Render edit form
function renderEditForm(task) {
    return `
        <div class="edit-form">
            <input 
                type="text" 
                id="edit-name-${task.id}" 
                value="${escapeHtml(task.name)}"
                placeholder="Task name"
                maxlength="255"
            >
            <textarea 
                id="edit-description-${task.id}" 
                placeholder="Task description (optional)"
                rows="3"
            >${escapeHtml(task.description || '')}</textarea>
            <div class="edit-actions">
                <button class="btn btn-primary" onclick="saveEdit(${task.id})">
                    💾 Save
                </button>
                <button class="btn btn-secondary" onclick="cancelEdit()">
                    ✖️ Cancel
                </button>
            </div>
        </div>
    `;
}

// Handle add task
async function handleAddTask(e) {
    e.preventDefault();
    
    const nameInput = document.getElementById('taskName');
    const descriptionInput = document.getElementById('taskDescription');
    
    const name = nameInput.value.trim();
    const description = descriptionInput.value.trim();
    
    if (!name) {
        showToast('Task name is required', 'error');
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE}/items`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ name, description })
        });
        
        if (!response.ok) {
            throw new Error('Failed to create task');
        }
        
        const newTask = await response.json();
        tasks.unshift(newTask);
        
        // Clear form
        nameInput.value = '';
        descriptionInput.value = '';
        
        renderTasks();
        updateTaskCount();
        showToast('Task added successfully!', 'success');
    } catch (error) {
        console.error('Failed to add task:', error);
        showToast('Failed to add task', 'error');
    }
}

// Start editing task
function startEdit(taskId) {
    editingTaskId = taskId;
    renderTasks();
}

// Cancel editing
function cancelEdit() {
    editingTaskId = null;
    renderTasks();
}

// Save edit
async function saveEdit(taskId) {
    const nameInput = document.getElementById(`edit-name-${taskId}`);
    const descriptionInput = document.getElementById(`edit-description-${taskId}`);
    
    const name = nameInput.value.trim();
    const description = descriptionInput.value.trim();
    
    if (!name) {
        showToast('Task name is required', 'error');
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE}/items/${taskId}`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ name, description })
        });
        
        if (!response.ok) {
            throw new Error('Failed to update task');
        }
        
        const updatedTask = await response.json();
        const index = tasks.findIndex(t => t.id === taskId);
        if (index !== -1) {
            tasks[index] = updatedTask;
        }
        
        editingTaskId = null;
        renderTasks();
        showToast('Task updated successfully!', 'success');
    } catch (error) {
        console.error('Failed to update task:', error);
        showToast('Failed to update task', 'error');
    }
}

// Delete task
async function deleteTask(taskId) {
    if (!confirm('Are you sure you want to delete this task?')) {
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE}/items/${taskId}`, {
            method: 'DELETE'
        });
        
        if (!response.ok) {
            throw new Error('Failed to delete task');
        }
        
        tasks = tasks.filter(t => t.id !== taskId);
        renderTasks();
        updateTaskCount();
        showToast('Task deleted successfully!', 'success');
    } catch (error) {
        console.error('Failed to delete task:', error);
        showToast('Failed to delete task', 'error');
    }
}

// Refresh tasks
function refreshTasks() {
    loadTasks();
    showToast('Tasks refreshed', 'success');
}

// Update task count
function updateTaskCount() {
    document.getElementById('totalTasks').textContent = tasks.length;
}

// Show toast notification
function showToast(message, type = 'success') {
    const toast = document.getElementById('toast');
    toast.textContent = message;
    toast.className = `toast ${type} show`;
    
    setTimeout(() => {
        toast.classList.remove('show');
    }, 3000);
}

// Escape HTML to prevent XSS
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}
