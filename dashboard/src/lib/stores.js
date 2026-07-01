import { writable } from 'svelte/store';
import { browser } from '$app/environment';

function createAuthStore() {
    const storedToken = browser ? localStorage.getItem('carebridge_token') : null;
    const storedUser = browser ? JSON.parse(localStorage.getItem('carebridge_user') || 'null') : null;
    
    const { subscribe, set, update } = writable({
        token: storedToken,
        user: storedUser,
        isAuthenticated: !!storedToken
    });
    
    return {
        subscribe,
        login: (token, user) => {
            if (browser) {
                localStorage.setItem('carebridge_token', token);
                localStorage.setItem('carebridge_user', JSON.stringify(user));
            }
            set({ token, user, isAuthenticated: true });
        },
        logout: () => {
            if (browser) {
                localStorage.removeItem('carebridge_token');
                localStorage.removeItem('carebridge_user');
            }
            set({ token: null, user: null, isAuthenticated: false });
        }
    };
}

export const auth = createAuthStore();

// UI store for sidebar state
export const sidebarOpen = writable(true);

// Notification store
export const notifications = writable([]);

export function addNotification(message, type = 'success', duration = 4000) {
    const id = Date.now();
    notifications.update(n => [...n, { id, message, type }]);
    setTimeout(() => {
        notifications.update(n => n.filter(notif => notif.id !== id));
    }, duration);
}
