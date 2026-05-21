// API Client
function getToken() { return localStorage.getItem('token'); }

function logout() {
    localStorage.removeItem('token');
    localStorage.removeItem('username');
    localStorage.removeItem('role');
    window.location.href = '/login.html';
}

async function api(url, options = {}) {
    const token = getToken();
    if (!token && !url.includes('/api/auth/login')) {
        window.location.href = '/login.html';
        return null;
    }
    const headers = { ...options.headers };
    if (token) headers['Authorization'] = `Bearer ${token}`;
    if (options.body && typeof options.body === 'object') {
        headers['Content-Type'] = 'application/json';
        options.body = JSON.stringify(options.body);
    }
    try {
        const res = await fetch(url, { ...options, headers });
        if (res.status === 401) { logout(); return null; }
        if (!res.ok) {
            const data = await res.json().catch(() => ({}));
            throw new Error(data.error || `HTTP ${res.status}`);
        }
        const contentType = res.headers.get('Content-Type') || '';
        if (contentType.includes('json')) return res.json();
        return res;
    } catch (err) {
        console.error('API Error:', err);
        toast(err.message, 'error');
        throw err;
    }
}

// Toast notifications
function toast(message, type = 'info') {
    const existing = document.querySelector('.toast');
    if (existing) existing.remove();
    const el = document.createElement('div');
    el.className = 'toast';
    if (type === 'error') el.style.borderColor = '#f44336';
    el.textContent = message;
    document.body.appendChild(el);
    setTimeout(() => el.remove(), 3000);
}

// Init navigation
document.addEventListener('DOMContentLoaded', () => {
    // Highlight active nav item
    const path = window.location.pathname.split('/').pop() || 'index.html';
    document.querySelectorAll('.nav-item').forEach(el => {
        const href = el.getAttribute('href').split('/').pop();
        if (href === path || (path === '' && href === 'index.html')) {
            el.classList.add('active');
        } else {
            el.classList.remove('active');
        }
    });

    // Set user info
    const userInfo = document.getElementById('userInfo');
    if (userInfo) {
        const username = localStorage.getItem('username');
        const role = localStorage.getItem('role');
        if (username) userInfo.textContent = `${username} (${role})`;
    }

    // Logout button
    const logoutBtn = document.getElementById('logoutBtn');
    if (logoutBtn) logoutBtn.addEventListener('click', (e) => { e.preventDefault(); logout(); });

    // Check auth
    if (!getToken() && !window.location.pathname.includes('login')) {
        window.location.href = '/login.html';
    }
});
