const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:3000';

/**
 * Core fetch wrapper with auth token support and consistent error handling.
 */
async function request(path, options = {}) {
    const token = typeof localStorage !== 'undefined' ? localStorage.getItem('carebridge_token') : null;

    const res = await fetch(`${API_URL}${path}`, {
        ...options,
        headers: {
            'Content-Type': 'application/json',
            ...(token ? { Authorization: `Bearer ${token}` } : {}),
            ...options.headers
        }
    });

    const data = await res.json().catch(() => ({}));

    if (!res.ok) {
        throw new Error(data.error || data.message || `Request failed (${res.status})`);
    }

    return data;
}

// ─── Auth ────────────────────────────────────────────────────────────────────

export function register(email, password, firstName, lastName, role = 'caregiver') {
    return request('/api/auth/register', {
        method: 'POST',
        body: JSON.stringify({ email, password, firstName, lastName, role })
    });
}

export function login(email, password) {
    return request('/api/auth/login', {
        method: 'POST',
        body: JSON.stringify({ email, password })
    });
}

export function getMe() {
    return request('/api/auth/me');
}

// ─── Patients ─────────────────────────────────────────────────────────────────

export function getPatients() {
    return request('/api/patients');
}

export function getPatient(id) {
    return request(`/api/patients/${id}`);
}

export function createPatient(data) {
    return request('/api/patients', { method: 'POST', body: JSON.stringify(data) });
}

export function updatePatient(id, data) {
    return request(`/api/patients/${id}`, { method: 'PUT', body: JSON.stringify(data) });
}

// ─── Wellness ─────────────────────────────────────────────────────────────────

export function submitWellnessCheckin(data) {
    return request('/api/wellness', { method: 'POST', body: JSON.stringify(data) });
}

export function getWellnessHistory(patientId) {
    return request(`/api/wellness/${patientId}`);
}

// ─── Medications ─────────────────────────────────────────────────────────────

export function getMedications(patientId) {
    return request(`/api/medications/${patientId}`);
}

export function createMedication(data) {
    return request('/api/medications', { method: 'POST', body: JSON.stringify(data) });
}

export function updateMedication(id, data) {
    return request(`/api/medications/${id}`, { method: 'PUT', body: JSON.stringify(data) });
}

export function deleteMedication(id) {
    return request(`/api/medications/${id}`, { method: 'DELETE' });
}

// ─── Appointments ─────────────────────────────────────────────────────────────

export function getAppointments(patientId) {
    return request(`/api/appointments/${patientId}`);
}

export function createAppointment(data) {
    return request('/api/appointments', { method: 'POST', body: JSON.stringify(data) });
}

export function updateAppointment(id, data) {
    return request(`/api/appointments/${id}`, { method: 'PUT', body: JSON.stringify(data) });
}

export function deleteAppointment(id) {
    return request(`/api/appointments/${id}`, { method: 'DELETE' });
}

// ─── Journal ──────────────────────────────────────────────────────────────────

export function getJournalEntries(patientId) {
    return request(`/api/journal/${patientId}`);
}

export function createJournalEntry(data) {
    return request('/api/journal', { method: 'POST', body: JSON.stringify(data) });
}

// ─── Care Notes ───────────────────────────────────────────────────────────────

export function getCareNotes(patientId) {
    return request(`/api/care-notes/${patientId}`);
}

export function createCareNote(data) {
    return request('/api/care-notes', { method: 'POST', body: JSON.stringify(data) });
}

// ─── AI ───────────────────────────────────────────────────────────────────────

export function getAiInsights(patientId) {
    return request(`/api/ai/insights/${patientId}`);
}

export function generateAiSummary(patientId) {
    return request(`/api/ai/summary/${patientId}`, { method: 'POST' });
}
