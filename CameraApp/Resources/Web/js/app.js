// Web UI Version Diagnostics & Safe Reload
window.WEB_UI_VERSION = '2.5.2';
console.info('[Mac Monitor] Web UI version:', window.WEB_UI_VERSION);

(function() {
    function initDiagnostics() {
        if (!document.body) return;
        document.body.dataset.webUiVersion = '2.5.2';

        // Enhanced Telegram.WebApp integration (container only — no bot commands)
        if (window.Telegram?.WebApp) {
            const tg = Telegram.WebApp;
            document.body.classList.add('telegram-webview');
            document.body.dataset.telegram = 'true';
            try { tg.ready(); tg.expand(); } catch(e) {}

            // Theme detection
            if (tg.colorScheme === 'dark') document.body.classList.add('telegram-dark');
            else document.body.classList.add('telegram-light');

            // Apply theme params as CSS vars
            if (tg.themeParams) {
                const tp = tg.themeParams;
                if (tp.bg_color) document.documentElement.style.setProperty('--tg-bg', tp.bg_color);
                if (tp.text_color) document.documentElement.style.setProperty('--tg-text', tp.text_color);
                if (tp.button_color) document.documentElement.style.setProperty('--tg-accent', tp.button_color);
            }

            // Safe area insets
            if (tg.safeAreaInset) {
                const s = tg.safeAreaInset;
                document.documentElement.style.setProperty('--tg-safe-top', s.top + 'px');
                document.documentElement.style.setProperty('--tg-safe-bottom', s.bottom + 'px');
            }

            // i18n stale safeguard reload
            if (typeof t === 'function' && t('systemNormal') === 'systemNormal') {
                if (!sessionStorage.getItem('forcedReloadForAssets')) {
                    sessionStorage.setItem('forcedReloadForAssets', '1');
                    console.warn('[Mac Monitor] Stale resources detected. Triggering asset force refresh.');
                    location.reload();
                }
            }
        }
    }
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initDiagnostics);
    } else {
        initDiagnostics();
    }
})();

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
            const err = new Error(data.error || `HTTP ${res.status}`);
            err.status = res.status;
            throw err;
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

async function optionalApi(url, options = {}) {
    const token = getToken();
    const headers = { ...(options.headers || {}) };
    if (token) headers['Authorization'] = `Bearer ${token}`;
    if (options.body && typeof options.body === 'object') {
        headers['Content-Type'] = 'application/json';
        options.body = JSON.stringify(options.body);
    }
    try {
        const res = await fetch(url, { ...options, headers });
        if (res.status === 401) { logout(); return null; }
        if (!res.ok) {
            console.warn('[Optional API]', url, res.status);
            return null;
        }
        const contentType = res.headers.get('Content-Type') || '';
        if (contentType.includes('json')) return await res.json();
        return res;
    } catch (e) {
        console.warn('[Optional API failed]', url, e);
        return null;
    }
}

async function apiSilent(url, options = {}) {
    return optionalApi(url, options);
}

// Toast notifications
function toast(message, type = 'info') {
    const existing = document.querySelector('.toast');
    if (existing) existing.remove();
    const el = document.createElement('div');
    el.className = 'toast';
    
    let icon = '';
    if (type === 'error') {
        icon = '<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="var(--danger)" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="12"></line><line x1="12" y1="16" x2="12.01" y2="16"></line></svg>';
    } else if (type === 'success') {
        icon = '<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="var(--success)" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>';
    } else {
        icon = '<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="var(--accent)" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="16" x2="12" y2="12"></line><line x1="12" y1="8" x2="12.01" y2="8"></line></svg>';
    }
    
    el.innerHTML = `${icon}<span>${message}</span>`;
    document.body.appendChild(el);
    setTimeout(() => {
        el.style.opacity = '0';
        el.style.transform = 'translateY(10px) scale(0.95)';
        el.style.transition = 'opacity 0.2s, transform 0.2s';
        setTimeout(() => el.remove(), 200);
    }, 3000);
}

// ===== v2.5.0 Global Utilities =====

// Status dot helper (was duplicated in index/remote/health)
window.dot = (status, labels) => {
    const map = { running:'dot-green', active:'dot-green', connected:'dot-green', ok:'dot-green',
                  stopped:'dot-gray', idle:'dot-gray', disconnected:'dot-gray',
                  starting:'dot-orange', stopping:'dot-orange', retrying:'dot-orange', uploading:'dot-orange',
                  error:'dot-red', failed:'dot-red', offline:'dot-red' };
    const cls = map[status] || 'dot-gray';
    const label = (labels && labels[status]) || status || '';
    return `<span class="status-dot ${cls}"></span> ${label}`;
};

// Debounce helper (was duplicated in media/logs)
window.debounce = (fn, ms) => { let t; return (...a) => { clearTimeout(t); t = setTimeout(() => fn(...a), ms); }; };

// Set page title from <title data-i18n> element
window.setPageTitle = () => {
    const titleEl = document.querySelector('title[data-i18n]');
    if (titleEl && typeof t === 'function') document.title = t(titleEl.dataset.i18n) + ' — ' + t('macMonitorSystem');
};

// Role helpers
window.getRole = () => localStorage.getItem('role') || 'viewer';
window.isAdmin = () => getRole() === 'admin';
window.isOperatorOrAdmin = () => { const r = getRole(); return r === 'admin' || r === 'operator'; };

// Apply role visibility to elements with data-role-min="operator" or "admin"
window.applyRoleVisibility = () => {
    const roleLevel = { viewer:0, operator:1, admin:2 };
    const currentLevel = roleLevel[getRole()] ?? 0;
    document.querySelectorAll('[data-role-min]').forEach(el => {
        const minRole = el.getAttribute('data-role-min');
        const minLevel = roleLevel[minRole] ?? 0;
        if (currentLevel < minLevel) {
            if (el.dataset.roleAction === 'disable') {
                el.classList.add('role-disabled');
                el.title = (typeof t === 'function' && t('adminOnlyAction')) || 'Insufficient permissions';
            } else {
                el.classList.add('role-hidden');
            }
        } else {
            el.classList.remove('role-hidden', 'role-disabled');
        }
    });
};

// Lightweight polling helper with visibility pause and error backoff
window.createPoller = (name, fetchFn, renderFn, intervalMs, opts = {}) => {
    const state = { timer: null, interval: intervalMs, consecutiveErrors: 0 };
    const tick = async () => {
        if (document.hidden && opts.pauseWhenHidden !== false) return;
        try {
            const data = await fetchFn();
            state.consecutiveErrors = 0;
            if (renderFn) renderFn(data);
        } catch (e) {
            state.consecutiveErrors++;
            if (state.consecutiveErrors > 3 && opts.backoff !== false) {
                clearInterval(state.timer);
                state.interval = Math.min(state.interval * 2, 60000);
                state.timer = setInterval(tick, state.interval);
            }
            if (!opts.silent) console.warn(`[${name}] poll error:`, e);
        }
    };
    const onVis = () => { if (!document.hidden) tick(); };
    document.addEventListener('visibilitychange', onVis);
    state.timer = setInterval(tick, intervalMs);
    tick();
    return { stop: () => { clearInterval(state.timer); document.removeEventListener('visibilitychange', onVis); }, tick, state };
};

// Initialize Navigation and System Environment
document.addEventListener('DOMContentLoaded', () => {
    // Check Authentication first
    const isLoginPage = window.location.pathname.includes('login');
    if (!getToken() && !isLoginPage) {
        window.location.href = '/login.html';
        return;
    }

    // Inject Unified Navigation if not on login page
    if (!isLoginPage) {
        setupNavigation();
    }

    // Apply i18n
    if (typeof applyI18N === 'function') applyI18N();

    // Apply role visibility after navigation and i18n are ready
    if (typeof applyRoleVisibility === 'function') applyRoleVisibility();

    // Set page title from i18n
    if (typeof setPageTitle === 'function') setPageTitle();
});

// Setup Navigation layouts dynamically
function setupNavigation() {
    const sidebarEl = document.querySelector('nav.sidebar');
    const overlayEl = document.getElementById('sidebarOverlay');
    
    // Inject Desktop Sidebar contents
    if (sidebarEl) {
        sidebarEl.innerHTML = `
            <div class="sidebar-header">
                <svg class="sidebar-brand-icon" viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="3" width="20" height="14" rx="2" ry="2"></rect><line x1="8" y1="21" x2="16" y2="21"></line><line x1="12" y1="17" x2="12" y2="21"></line></svg>
                <span data-i18n="appName">Mac Monitor</span>
            </div>
            <div class="sidebar-menu">
                <a href="/" class="nav-item" data-nav="index.html">
                    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="9" rx="1"></rect><rect x="14" y="3" width="7" height="5" rx="1"></rect><rect x="14" y="12" width="7" height="9" rx="1"></rect><rect x="3" y="16" width="7" height="5" rx="1"></rect></svg>
                    <span data-i18n="dashboard">Dashboard</span>
                </a>
                <a href="/live.html" class="nav-item" data-nav="live.html">
                    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M23 7a2 2 0 0 0-2-2h-4.2l-1.4-2.1A2 2 0 0 0 13.8 2H10.2a2 2 0 0 0-1.6.9L7.2 5H3a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h18a2 2 0 0 0 2-2V7z"></path><circle cx="12" cy="13" r="4"></circle></svg>
                    <span data-i18n="liveView">Live View</span>
                </a>
                <a href="/media.html" class="nav-item" data-nav="media.html">
                    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect><circle cx="8.5" cy="8.5" r="1.5"></circle><polyline points="21 15 16 10 5 21"></polyline></svg>
                    <span data-i18n="mediaLibrary">Media Library</span>
                </a>
                <a href="/tasks.html" class="nav-item" data-nav="tasks.html">
                    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"></rect><line x1="16" y1="2" x2="16" y2="6"></line><line x1="8" y1="2" x2="8" y2="6"></line><line x1="3" y1="10" x2="21" y2="10"></line></svg>
                    <span data-i18n="automation">Automation</span>
                </a>
                <a href="/uploads.html" class="nav-item" data-nav="uploads.html">
                    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20.39 18.39A5 5 0 0 0 18 9h-1.26A8 8 0 1 0 3 16.3"></path><path d="M16 16l-4-4-4 4M12 12v9"></path></svg>
                    <span data-i18n="uploadQueue">Upload Queue</span>
                </a>
                <a href="/remote.html" class="nav-item" data-nav="remote.html">
                    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect><path d="M7 11V7a5 5 0 0 1 10 0v4"></path></svg>
                    <span data-i18n="remoteAccess">Remote Access</span>
                </a>
                <a href="/storage.html" class="nav-item" data-nav="storage.html">
                    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><ellipse cx="12" cy="5" rx="9" ry="3"></ellipse><path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5"></path><path d="M3 12c0 1.66 4 3 9 3s9-1.34 9-3"></path></svg>
                    <span data-i18n="storageCenter">Storage Center</span>
                </a>
                <a href="/health.html" class="nav-item" data-nav="health.html">
                    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 12h-4l-3 9L9 3l-3 9H2"></path></svg>
                    <span data-i18n="health">Health</span>
                </a>
                <a href="/logs.html" class="nav-item" data-nav="logs.html">
                    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="8" y1="6" x2="21" y2="6"></line><line x1="8" y1="12" x2="21" y2="12"></line><line x1="8" y1="18" x2="21" y2="18"></line><line x1="3" y1="6" x2="3.01" y2="6"></line><line x1="3" y1="12" x2="3.01" y2="12"></line><line x1="3" y1="18" x2="3.01" y2="18"></line></svg>
                    <span data-i18n="activityLog">Activity Log</span>
                </a>
                <a href="/audit.html" class="nav-item" data-nav="audit.html">
                    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22c5.523 0 10-4.477 10-10S17.523 2 12 2 2 6.477 2 12s4.477 10 10 10z"></path><path d="M12 6v6l4 2"></path></svg>
                    <span data-i18n="auditLog">Audit Log</span>
                </a>
                <a href="/settings.html" class="nav-item" data-nav="settings.html">
                    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"></circle><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"></path></svg>
                    <span data-i18n="settings">Settings</span>
                </a>
            </div>
            <div class="sidebar-footer">
                <span id="userInfo"></span>
                <a href="#" id="logoutBtn" class="logout">
                    <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9"/></svg>
                    <span data-i18n="logout">Logout</span>
                </a>
            </div>
        `;
    }

    // Inject Mobile Header
    if (!document.querySelector('.mobile-header')) {
        const header = document.createElement('header');
        header.className = 'mobile-header';
        header.innerHTML = `
            <button class="hamburger" id="menuBtn">
                <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="3" y1="12" x2="21" y2="12"></line><line x1="3" y1="6" x2="21" y2="6"></line><line x1="3" y1="18" x2="21" y2="18"></line></svg>
            </button>
            <div class="mobile-brand" data-i18n="appName">Mac Monitor</div>
            <div style="width: 38px;"></div>
        `;
        document.body.prepend(header);
    }

    // Inject Mobile Bottom Tab Bar
    if (!document.querySelector('.mobile-tabbar')) {
        const tabbar = document.createElement('nav');
        tabbar.className = 'mobile-tabbar';
        tabbar.innerHTML = `
            <a href="/" class="tab-item" data-tab="index.html">
                <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="9" rx="1"></rect><rect x="14" y="3" width="7" height="5" rx="1"></rect><rect x="14" y="12" width="7" height="9" rx="1"></rect><rect x="3" y="16" width="7" height="5" rx="1"></rect></svg>
                <span data-i18n="home">Home</span>
            </a>
            <a href="/live.html" class="tab-item" data-tab="live.html">
                <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M23 7a2 2 0 0 0-2-2h-4.2l-1.4-2.1A2 2 0 0 0 13.8 2H10.2a2 2 0 0 0-1.6.9L7.2 5H3a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h18a2 2 0 0 0 2-2V7z"></path><circle cx="12" cy="13" r="4"></circle></svg>
                <span data-i18n="liveView">Live</span>
            </a>
            <a href="/media.html" class="tab-item" data-tab="media.html">
                <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect><circle cx="8.5" cy="8.5" r="1.5"></circle><polyline points="21 15 16 10 5 21"></polyline></svg>
                <span data-i18n="mediaLibrary">Media</span>
            </a>
            <a href="/tasks.html" class="tab-item" data-tab="tasks.html">
                <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"></rect><line x1="16" y1="2" x2="16" y2="6"></line><line x1="8" y1="2" x2="8" y2="6"></line><line x1="3" y1="10" x2="21" y2="10"></line></svg>
                <span data-i18n="automation">Tasks</span>
            </a>
            <a href="#" class="tab-item" id="moreTabBtn">
                <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="1"></circle><circle cx="19" cy="12" r="1"></circle><circle cx="5" cy="12" r="1"></circle></svg>
                <span data-i18n="more">More</span>
            </a>
        `;
        document.body.appendChild(tabbar);
    }

    // Inject Mobile "More" Slide-up Menu
    if (!document.getElementById('moreSheetOverlay')) {
        const moreSheet = document.createElement('div');
        moreSheet.className = 'more-sheet-overlay';
        moreSheet.id = 'moreSheetOverlay';
        moreSheet.innerHTML = `
            <div class="more-sheet">
                <div class="more-sheet-header">
                    <h3 data-i18n="more">More</h3>
                    <button class="more-sheet-close" id="moreSheetCloseBtn">&times;</button>
                </div>
                <div class="more-sheet-grid">
                    <a href="/uploads.html" class="more-grid-item">
                        <div class="more-icon-wrap upload"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20.39 18.39A5 5 0 0 0 18 9h-1.26A8 8 0 1 0 3 16.3"></path><path d="M16 16l-4-4-4 4M12 12v9"></path></svg></div>
                        <span data-i18n="uploadQueue">Uploads</span>
                    </a>
                    <a href="/remote.html" class="more-grid-item">
                        <div class="more-icon-wrap remote"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect><path d="M7 11V7a5 5 0 0 1 10 0v4"></path></svg></div>
                        <span data-i18n="remoteAccess">Remote</span>
                    </a>
                    <a href="/storage.html" class="more-grid-item">
                        <div class="more-icon-wrap storage"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><ellipse cx="12" cy="5" rx="9" ry="3"></ellipse><path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5"></path><path d="M3 12c0 1.66 4 3 9 3s9-1.34 9-3"></path></svg></div>
                        <span data-i18n="storageCenter">Storage</span>
                    </a>
                    <a href="/health.html" class="more-grid-item">
                        <div class="more-icon-wrap health"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 12h-4l-3 9L9 3l-3 9H2"></path></svg></div>
                        <span data-i18n="health">Health</span>
                    </a>
                    <a href="/logs.html" class="more-grid-item">
                        <div class="more-icon-wrap logs"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="8" y1="6" x2="21" y2="6"></line><line x1="8" y1="12" x2="21" y2="12"></line><line x1="8" y1="18" x2="21" y2="18"></line><line x1="3" y1="6" x2="3.01" y2="6"></line><line x1="3" y1="12" x2="3.01" y2="12"></line><line x1="3" y1="18" x2="3.01" y2="18"></line></svg></div>
                        <span data-i18n="activityLog">Logs</span>
                    </a>
                    <a href="/audit.html" class="more-grid-item">
                        <div class="more-icon-wrap audit"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22c5.523 0 10-4.477 10-10S17.523 2 12 2 2 6.477 2 12s4.477 10 10 10z"></path><path d="M12 6v6l4 2"></path></svg></div>
                        <span data-i18n="auditLog">Audit</span>
                    </a>
                    <a href="/settings.html" class="more-grid-item">
                        <div class="more-icon-wrap settings"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"></circle><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"></path></svg></div>
                        <span data-i18n="settings">Settings</span>
                    </a>
                    <a href="#" class="more-grid-item" id="moreLogoutBtn">
                        <div class="more-icon-wrap" style="color:var(--danger);"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9"/></svg></div>
                        <span data-i18n="logout">Logout</span>
                    </a>
                </div>
            </div>
        </div>
        `;
        document.body.appendChild(moreSheet);
    }

    // Set Active Highlighting
    const path = window.location.pathname.split('/').pop() || 'index.html';
    
    // Highlight sidebar links (Desktop)
    document.querySelectorAll('.sidebar .nav-item').forEach(el => {
        const href = el.getAttribute('href').split('/').pop() || 'index.html';
        if (href === path || (path === '' && href === 'index.html')) {
            el.classList.add('active');
        } else {
            el.classList.remove('active');
        }
    });

    // Highlight bottom tab links (Mobile)
    document.querySelectorAll('.mobile-tabbar .tab-item').forEach(el => {
        const tab = el.getAttribute('data-tab');
        if (tab && (tab === path || (path === '' && tab === 'index.html'))) {
            el.classList.add('active');
        } else {
            el.classList.remove('active');
        }
    });

    // Setup Event Listeners
    // Desktop Logout
    const logoutBtn = document.getElementById('logoutBtn');
    if (logoutBtn) logoutBtn.addEventListener('click', (e) => { e.preventDefault(); logout(); });

    // Mobile Logout
    const moreLogoutBtn = document.getElementById('moreLogoutBtn');
    if (moreLogoutBtn) moreLogoutBtn.addEventListener('click', (e) => { e.preventDefault(); logout(); });

    // Hamburger sidebar toggle on mobile
    const hamburger = document.getElementById('menuBtn');
    if (hamburger && sidebarEl) {
        hamburger.addEventListener('click', () => {
            sidebarEl.classList.toggle('open');
            if (overlayEl) overlayEl.classList.toggle('active');
        });
        if (overlayEl) {
            overlayEl.addEventListener('click', () => {
                sidebarEl.classList.remove('open');
                overlayEl.classList.remove('active');
            });
        }
    }

    // Bottom tab "More" toggle listener
    const moreTabBtn = document.getElementById('moreTabBtn');
    const moreOverlay = document.getElementById('moreSheetOverlay');
    const moreSheetClose = document.getElementById('moreSheetCloseBtn');
    
    if (moreTabBtn && moreOverlay) {
        moreTabBtn.addEventListener('click', (e) => {
            e.preventDefault();
            moreOverlay.style.display = 'flex';
            // Force redraw before adding transform class
            moreOverlay.offsetHeight;
            moreOverlay.querySelector('.more-sheet').classList.add('show');
        });
        
        const closeMore = () => {
            const sheet = moreOverlay.querySelector('.more-sheet');
            sheet.classList.remove('show');
            setTimeout(() => {
                moreOverlay.style.display = 'none';
            }, 300);
        };

        if (moreSheetClose) moreSheetClose.addEventListener('click', closeMore);
        moreOverlay.addEventListener('click', (e) => {
            if (e.target === moreOverlay) closeMore();
        });
    }

    // Show Username & User info in Sidebar
    const userInfo = document.getElementById('userInfo');
    if (userInfo) {
        const username = localStorage.getItem('username');
        const role = localStorage.getItem('role');
        if (username) userInfo.textContent = `${username} (${role})`;
    }
}
