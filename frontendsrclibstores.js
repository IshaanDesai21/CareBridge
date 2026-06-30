import { writable } from 'svelte/store';
import { browser } from '$app/environment';

function createAuthStore() {
    const storedToken = browser ? localStorage.getItem('token') : null;
    const storedUser = browser ? JSON.parse(localStorage.getItem('user') || 'null') : null;
    
    const { subscribe, set, update } = writable({
        token: storedToken,
        user: storedUser,
        isAuthenticated: !!storedToken
    });
    
    return {
        subscribe,
        login: (token, user) => {
            if (browser) {
                localStorage.setItem('token', token);
                localStorage.setItem('user', JSON.stringify(user));
            }
            set({ token, user, isAuthenticated: true });
        },
        logout: () => {
            if (browser) {
                localStorage.removeItem('token');
                localStorage.removeItem('user');
            }
            set({ token: null, user: null, isAuthenticated: false });
        }
    };
}

export const auth = createAuthStore();
