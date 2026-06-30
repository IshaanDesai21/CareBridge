const API_URL = 'http://localhost:3000';

export async function register(email, password, firstName, lastName) {
    const response = await fetch(`${API_URL}/api/auth/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password, firstName, lastName })
    });
    
    if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'Registration failed');
    }
    
    return await response.json();
}

export async function login(email, password) {
    const response = await fetch(`${API_URL}/api/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password })
    });
    
    if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'Login failed');
    }
    
    return await response.json();
}

export async function getPatients() {
    const response = await fetch(`${API_URL}/api/patients`);
    if (!response.ok) throw new Error('Failed to fetch patients');
    return await response.json();
}

export async function submitWellnessCheckin(data) {
    const response = await fetch(`${API_URL}/api/wellness`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    });
    
    if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'Check-in failed');
    }
    
    return await response.json();
}

export async function getWellnessHistory(patientId) {
    const response = await fetch(`${API_URL}/api/wellness/${patientId}`);
    if (!response.ok) throw new Error('Failed to fetch history');
    return await response.json();
}
