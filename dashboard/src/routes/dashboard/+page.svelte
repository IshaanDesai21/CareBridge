<script>
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { auth, addNotification } from '$lib/stores';
	import CustomSelect from '$lib/components/CustomSelect.svelte';

	// ─── Demo mode toggle ─────────────────────
	// Live backend mode: data persists to the API/database.
	const DEMO_MODE = false;

	import {
		getPatients, submitWellnessCheckin, getWellnessHistory, getCareNotes,
		createCareNote, getMedications, createMedication, getAiInsights,
		getLinkedPatient, familyLink, getPatientJoinCode, getPatientDetails,
		getAiOverview, getAlerts, acknowledgeAlert,
		getMyOrganization, createOrganization, joinOrganization
	} from '$lib/api';

	// ─── Static demo data ────────────────────────────────────────────────────
	const DEMO_USER = { id: 1, firstName: 'Sarah', lastName: 'Mitchell', email: 'sarah@carebridge.com', role: 'caregiver' };

	const DEMO_PATIENTS = [
		{ id: 1, first_name: 'Margaret', last_name: 'Chen', wellness_score: 42, updated_at: new Date(Date.now() - 3_600_000).toISOString() },
		{ id: 2, first_name: 'Robert', last_name: 'Okafor', wellness_score: 67, updated_at: new Date(Date.now() - 7_200_000).toISOString() },
		{ id: 3, first_name: 'Eleanor', last_name: 'Vasquez', wellness_score: 84, updated_at: new Date(Date.now() - 86_400_000).toISOString() }
	];

	const DEMO_ALERTS = [
		{ id: 1, patient_name: 'Margaret Chen', message: 'URGENT: Patient needs immediate assistance', is_urgent: 1, is_acknowledged: 0, created_at: new Date(Date.now() - 1_800_000).toISOString() },
		{ id: 2, patient_name: 'Robert Okafor', message: 'Patient would like to speak with their caregiver', is_urgent: 0, is_acknowledged: 0, created_at: new Date(Date.now() - 5_400_000).toISOString() }
	];

	const DEMO_WELLNESS = {
		1: [
			{ id: 1, patient_id: 1, date: '2026-07-01', energy: 3, mood: 3, pain: 8, fatigue: 8, appetite: 4, hydration: 3, breathing: 5, mobility: 4, balance: 4, speech_clarity: 7, swallowing_difficulty: 6, sleep_quality: 3, weight: 68.2, notes: 'Experienced increased pain in left knee. Slept poorly.', created_at: new Date(Date.now() - 3_600_000).toISOString() },
			{ id: 2, patient_id: 1, date: '2026-06-30', energy: 4, mood: 4, pain: 7, fatigue: 7, appetite: 4, hydration: 4, breathing: 5, mobility: 4, balance: 4, speech_clarity: 6, swallowing_difficulty: 5, sleep_quality: 4, weight: 68.5, notes: 'Dizziness after morning meds.', created_at: new Date(Date.now() - 90_000_000).toISOString() },
			{ id: 3, patient_id: 1, date: '2026-06-29', energy: 5, mood: 5, pain: 6, fatigue: 6, appetite: 5, hydration: 5, breathing: 6, mobility: 5, balance: 5, speech_clarity: 6, swallowing_difficulty: 5, sleep_quality: 5, weight: 68.9, notes: null, created_at: new Date(Date.now() - 176_400_000).toISOString() },
			{ id: 4, patient_id: 1, date: '2026-06-28', energy: 4, mood: 4, pain: 7, fatigue: 7, appetite: 4, hydration: 4, breathing: 5, mobility: 4, balance: 4, speech_clarity: 6, swallowing_difficulty: 6, sleep_quality: 4, weight: 69.1, notes: null, created_at: new Date(Date.now() - 262_800_000).toISOString() }
		],
		2: [
			{ id: 5, patient_id: 2, date: '2026-07-01', energy: 6, mood: 7, pain: 3, fatigue: 4, appetite: 7, hydration: 7, breathing: 7, mobility: 7, balance: 7, speech_clarity: 8, swallowing_difficulty: 3, sleep_quality: 7, weight: 82.0, notes: 'Good day. Enjoyed afternoon walk with family.', created_at: new Date(Date.now() - 7_200_000).toISOString() },
			{ id: 6, patient_id: 2, date: '2026-06-30', energy: 7, mood: 6, pain: 4, fatigue: 5, appetite: 6, hydration: 6, breathing: 7, mobility: 6, balance: 7, speech_clarity: 8, swallowing_difficulty: 3, sleep_quality: 6, weight: 82.3, notes: null, created_at: new Date(Date.now() - 93_600_000).toISOString() },
			{ id: 7, patient_id: 2, date: '2026-06-29', energy: 5, mood: 7, pain: 4, fatigue: 5, appetite: 7, hydration: 6, breathing: 6, mobility: 6, balance: 6, speech_clarity: 7, swallowing_difficulty: 4, sleep_quality: 6, weight: 82.3, notes: null, created_at: new Date(Date.now() - 180_000_000).toISOString() }
		],
		3: [
			{ id: 8, patient_id: 3, date: '2026-07-01', energy: 8, mood: 9, pain: 2, fatigue: 3, appetite: 8, hydration: 8, breathing: 9, mobility: 8, balance: 9, speech_clarity: 9, swallowing_difficulty: 2, sleep_quality: 8, weight: 61.5, notes: 'Excellent day. Family visit boosted spirits. Completed all exercises.', created_at: new Date(Date.now() - 86_400_000).toISOString() },
			{ id: 9, patient_id: 3, date: '2026-06-30', energy: 8, mood: 8, pain: 2, fatigue: 2, appetite: 8, hydration: 8, breathing: 9, mobility: 8, balance: 8, speech_clarity: 9, swallowing_difficulty: 2, sleep_quality: 9, weight: 61.7, notes: null, created_at: new Date(Date.now() - 172_800_000).toISOString() },
			{ id: 10, patient_id: 3, date: '2026-06-29', energy: 7, mood: 8, pain: 3, fatigue: 3, appetite: 8, hydration: 7, breathing: 8, mobility: 8, balance: 8, speech_clarity: 9, swallowing_difficulty: 2, sleep_quality: 8, weight: 61.9, notes: null, created_at: new Date(Date.now() - 259_200_000).toISOString() }
		]
	};

	const DEMO_MEDS = {
		1: [
			{ id: 1, name: 'Metformin', dosage: '500mg', frequency: 'Twice daily', is_active: 1 },
			{ id: 2, name: 'Lisinopril', dosage: '10mg', frequency: 'Once daily (morning)', is_active: 1 },
			{ id: 3, name: 'Atorvastatin', dosage: '20mg', frequency: 'Once daily (evening)', is_active: 1 },
			{ id: 4, name: 'Aspirin', dosage: '81mg', frequency: 'Once daily', is_active: 1 }
		],
		2: [
			{ id: 5, name: 'Amlodipine', dosage: '5mg', frequency: 'Once daily', is_active: 1 },
			{ id: 6, name: 'Omeprazole', dosage: '20mg', frequency: 'Once daily (before breakfast)', is_active: 1 },
			{ id: 7, name: 'Vitamin D3', dosage: '2000 IU', frequency: 'Once daily', is_active: 1 }
		],
		3: [
			{ id: 8, name: 'Levothyroxine', dosage: '50mcg', frequency: 'Once daily (fasting)', is_active: 1 },
			{ id: 9, name: 'Calcium + Magnesium', dosage: '500mg / 250mg', frequency: 'Twice daily with meals', is_active: 1 }
		]
	};

	const DEMO_NOTES = {
		1: [
			{ id: 1, note_type: 'observation', content: 'Patient appeared fatigued during morning rounds. Left knee visibly swollen — applying ice pack as instructed. Appetite reduced at lunch.', created_at: new Date(Date.now() - 3_600_000).toISOString() },
			{ id: 2, note_type: 'behavior', content: 'Margaret was more withdrawn than usual today. Mentioned missing her daughter\'s visits. Encouraged her to call family.', created_at: new Date(Date.now() - 90_000_000).toISOString() },
			{ id: 3, note_type: 'nutrition', content: 'Soft diet maintained. Patient struggling with hard foods — follow up with dietitian on texture modification.', created_at: new Date(Date.now() - 176_400_000).toISOString() }
		],
		2: [
			{ id: 4, note_type: 'observation', content: 'Robert completed his full physio exercises today with minimal assistance. Good improvement in balance.', created_at: new Date(Date.now() - 7_200_000).toISOString() },
			{ id: 5, note_type: 'communication', content: 'Family called to ask about weekend visit schedule. Confirmed Saturday afternoon is fine. Patient is very excited.', created_at: new Date(Date.now() - 93_600_000).toISOString() }
		],
		3: [
			{ id: 6, note_type: 'observation', content: 'Eleanor in great spirits. Completed morning yoga session independently. No concerns at this time.', created_at: new Date(Date.now() - 86_400_000).toISOString() },
			{ id: 7, note_type: 'equipment', content: 'Hearing aid battery replaced. Patient confirmed the new battery is working well.', created_at: new Date(Date.now() - 172_800_000).toISOString() }
		]
	};

	const DEMO_INSIGHTS = {
		1: [
			{ id: 1, insight_type: 'trend', title: 'Pain Levels Elevated', description: 'Margaret\'s pain scores have averaged 7.2/10 over the past 4 days, up from 5.1 the week prior. Consider medication review or physiotherapy referral.', severity: 'high', created_at: new Date(Date.now() - 3_600_000).toISOString() },
			{ id: 2, insight_type: 'trend', title: 'Sleep Quality Declining', description: 'Sleep quality scores have dropped from 6 to 3 over the past week, correlating with the increase in pain reports.', severity: 'medium', created_at: new Date(Date.now() - 90_000_000).toISOString() }
		],
		2: [
			{ id: 3, insight_type: 'trend', title: 'Mobility Improving', description: 'Robert\'s mobility and balance scores have shown steady improvement over the past 7 days, likely due to consistent physiotherapy.', severity: 'low', created_at: new Date(Date.now() - 7_200_000).toISOString() }
		],
		3: [
			{ id: 4, insight_type: 'summary', title: 'Consistently High Scores', description: 'Eleanor\'s wellness scores have remained above 80 for 3 consecutive weeks. No active concerns. Continue current care plan.', severity: 'low', created_at: new Date(Date.now() - 86_400_000).toISOString() }
		]
	};

	const DEMO_DETAILS = {
		1: {
			gender: 'female', height_cm: 158, weight_kg: 68.2, hearing_notes: 'Mild hearing loss in right ear. Prefers face-to-face communication.', vision_score: 'Wears reading glasses', medical_history: 'Type 2 Diabetes (2015), Hypertension (2018), Osteoarthritis — bilateral knees (2021)', diagnoses: ['Type 2 Diabetes', 'Hypertension', 'Osteoarthritis'], allergies: ['Penicillin', 'Sulfonamides'],
			emergency_contacts: [{ name: 'Linda Chen', relation: 'Daughter', phone: '(415) 555-0192', isPrimary: true }, { name: 'David Chen', relation: 'Son', phone: '(415) 555-0173', isPrimary: false }],
			ai_companion_name: 'Rose', care_team: [{ name: 'Dr. Priya Sharma', role: 'GP', organization: 'City Medical Centre' }, { name: 'James Whitfield', role: 'Physiotherapist', organization: 'Rehab Plus' }]
		},
		2: {
			gender: 'male', height_cm: 175, weight_kg: 82.0, hearing_notes: null, vision_score: '20/25 — mild correction needed', medical_history: 'Hypertension (2019), GERD (2020), Hip replacement surgery (2023)', diagnoses: ['Hypertension', 'GERD', 'Post hip replacement'], allergies: ['NSAIDs'],
			emergency_contacts: [{ name: 'Amara Okafor', relation: 'Wife', phone: '(212) 555-0141', isPrimary: true }],
			ai_companion_name: 'James', care_team: [{ name: 'Dr. Marcus Lee', role: 'GP', organization: 'Downtown Health' }, { name: 'Chloe Watts', role: 'Physiotherapist', organization: 'Rehab Plus' }]
		},
		3: {
			gender: 'female', height_cm: 163, weight_kg: 61.5, hearing_notes: 'Uses hearing aids in both ears.', vision_score: 'Wears bifocals', medical_history: 'Hypothyroidism (2010), Osteoporosis (2019)', diagnoses: ['Hypothyroidism', 'Osteoporosis'], allergies: [],
			emergency_contacts: [{ name: 'Carlos Vasquez', relation: 'Son', phone: '(310) 555-0167', isPrimary: true }, { name: 'Maria Vasquez', relation: 'Daughter-in-law', phone: '(310) 555-0188', isPrimary: false }],
			ai_companion_name: 'Alex', care_team: [{ name: 'Dr. Susan Park', role: 'GP', organization: 'Sunrise Medical' }]
		}
	};

	const DEMO_AI_OVERVIEWS = {
		1: 'Margaret Chen (42/100) presents with escalating pain levels averaging 7.2/10 over the past four days, accompanied by declining sleep quality and reduced appetite. Her bilateral osteoarthritis appears to be the primary driver — the left knee is visibly swollen and she reports increased difficulty with mobility. Immediate recommendations include pain medication review with Dr. Sharma, ice pack application TID, and a dietitian consult regarding soft diet adequacy. Ensure family contact is facilitated this week given her expressed loneliness.',
		2: 'Robert Okafor (67/100) is showing steady improvement post-hip-replacement, with mobility and balance scores trending upward over the past week. He remains compliant with medications and physiotherapy. The primary concern is ongoing blood pressure management — ensure Amlodipine adherence and schedule a BP review with Dr. Lee within the next 10 days. Overall trajectory is positive; no urgent interventions required.',
		3: 'Eleanor Vasquez (84/100) continues to perform exceptionally well across all wellness domains. She is fully independent in morning routines, compliant with Levothyroxine and calcium supplementation, and socially engaged. No clinical concerns at this time. Maintain current care plan and schedule routine thyroid function test at the next quarterly review.'
	};

	const DEMO_JOIN_CODES = { 1: 'MCH001', 2: 'ROK002', 3: 'ELV003' };

	// ─── App state ────────────────────────────────────────────────────────────
	let user = null;
	let loading = true;

	let patients = [];
	let alerts = [];
	let organization = null;
	let orgNameInput = '';
	let orgCodeInput = '';
	let orgBusy = false;
	let selectedPatient = null;
	let wellnessHistory = [];
	let careNotes = [];
	let aiInsights = [];
	let activeTab = 'all_patients';
	let sidebarCollapsed = false;
	let patientJoinCode = null;
	let patientDetails = null;
	let aiOverview = null;
	let generatingOverview = false;
	let expandedPatientId = null;

	let linkedPatient = null;
	let familyLinked = false;
	let familyTab = 'overview';
	let familyJoinCodeInput = '';
	let linkingCode = false;
	let familyWellness = [];
	let familyMeds = [];
	let familyNotes = [];

	const EMPTY_CHECKIN = {
		energy: 5, fatigue: 5, pain: 5, mood: 5, sleepQuality: 5, breathing: 5,
		mobility: 5, balance: 5, speechClarity: 5, appetite: 5, hydration: 5,
		swallowingDifficulty: 5, weight: '', notes: ''
	};
	let checkin = { ...EMPTY_CHECKIN };
	let submittingCheckin = false;
	let newNote = { content: '', note_type: 'observation' };
	let submittingNote = false;
	let caregiverMeds = [];
	let newMed = { name: '', dosage: '', frequency: '' };
	let submittingMed = false;

	const NOTE_TYPES = ['observation', 'behavior', 'equipment', 'nutrition', 'communication', 'question'];

	// ─── Mount ────────────────────────────────────────────────────────────────
	onMount(() => {
		if (DEMO_MODE) {
			user = DEMO_USER;
			patients = [...DEMO_PATIENTS].sort((a, b) => a.wellness_score - b.wellness_score);
			alerts = [...DEMO_ALERTS];
			loading = false;
			return;
		}
		const unsub = auth.subscribe(async state => {
			if (!state.isAuthenticated) { goto('/login'); return; }
			user = state.user;
			if (user.role === 'caregiver' || user.role === 'organization') {
				await loadCaregiverData();
				connectRealtime(state.token);
			} else if (user.role === 'family') {
				await loadFamilyData();
			}
			loading = false;
		});
		return () => { unsub(); disconnectRealtime(); };
	});

	// ─── Real-time alerts (patient "Call caregiver" over WebSocket) ─────────────
	let ws = null;
	let wsRetry = null;
	let wsClosedByUs = false;

	function connectRealtime(token) {
		if (!token || typeof window === 'undefined') return;
		if (ws && (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING)) return;
		const base = import.meta.env.VITE_API_URL || window.location.origin;
		const wsUrl = base.replace(/^http/, 'ws');
		try { ws = new WebSocket(wsUrl); } catch (e) { return; }

		ws.addEventListener('open', () => ws.send(JSON.stringify({ type: 'auth', token })));
		ws.addEventListener('message', async (ev) => {
			let msg;
			try { msg = JSON.parse(ev.data); } catch { return; }
			if (msg.type === 'notification' && msg.notification) {
				const n = msg.notification;
				addNotification(n.title || 'New alert', n.type === 'urgent' ? 'error' : 'success', 8000);
				// Refresh the Patient Alerts panel instantly so the call shows up live.
				try { const a = await getAlerts(); alerts = a.alerts || []; } catch {}
			}
		});
		ws.addEventListener('close', () => {
			if (wsClosedByUs) return;
			wsRetry = setTimeout(() => connectRealtime(token), 4000); // auto-reconnect
		});
		ws.addEventListener('error', () => { try { ws.close(); } catch {} });
	}

	function disconnectRealtime() {
		wsClosedByUs = true;
		if (wsRetry) clearTimeout(wsRetry);
		if (ws) { try { ws.close(); } catch {} ws = null; }
	}

	// ─── Data loading ─────────────────────────────────────────────────────────
	async function loadCaregiverData() {
		try {
			const [pResult, aResult, oResult] = await Promise.allSettled([getPatients(), getAlerts(), getMyOrganization()]);
			patients = ((pResult.value?.patients) || []).sort((a, b) => (a.wellness_score || 0) - (b.wellness_score || 0));
			alerts = aResult.value?.alerts || [];
			organization = oResult.value?.organization || null;
		} catch (e) {
			addNotification('Failed to load patients. Is the backend running?', 'error');
		}
	}

	async function handleCreateOrg() {
		if (!orgNameInput.trim()) return;
		orgBusy = true;
		try {
			const res = await createOrganization(orgNameInput.trim());
			organization = res.organization;
			orgNameInput = '';
			addNotification(`Organization "${organization.name}" created.`, 'success');
		} catch (e) { addNotification(e.message || 'Failed to create organization', 'error'); }
		finally { orgBusy = false; }
	}

	async function handleJoinOrg() {
		if (!orgCodeInput.trim()) return;
		orgBusy = true;
		try {
			await joinOrganization(orgCodeInput.trim().toUpperCase());
			orgCodeInput = '';
			await loadCaregiverData(); // refresh org + now-scoped patient/alert lists
			addNotification(`Joined ${organization?.name || 'organization'}.`, 'success');
		} catch (e) { addNotification(e.message || 'Failed to join organization', 'error'); }
		finally { orgBusy = false; }
	}

	async function loadFamilyData() {
		try {
			const result = await getLinkedPatient();
			familyLinked = result.linked; linkedPatient = result.patient;
			if (linkedPatient) {
				const [w, m, n] = await Promise.allSettled([
					getWellnessHistory(linkedPatient.id), getMedications(linkedPatient.id), getCareNotes(linkedPatient.id)
				]);
				familyWellness = w.value?.checkins || w.value?.history || [];
				familyMeds = m.value?.medications || m.value || [];
				familyNotes = n.value?.notes || n.value || [];
			}
		} catch (e) { console.error('Family data error:', e); }
	}

	async function selectPatient(patient) {
		selectedPatient = patient;
		expandedPatientId = patient.id;
		activeTab = 'overview';
		patientJoinCode = null; patientDetails = null; aiOverview = null; caregiverMeds = [];

		if (DEMO_MODE) {
			await new Promise(r => setTimeout(r, 120)); // brief loading feel
			wellnessHistory = DEMO_WELLNESS[patient.id] || [];
			careNotes = DEMO_NOTES[patient.id] || [];
			aiInsights = DEMO_INSIGHTS[patient.id] || [];
			patientJoinCode = DEMO_JOIN_CODES[patient.id] || null;
			patientDetails = DEMO_DETAILS[patient.id] || null;
			caregiverMeds = DEMO_MEDS[patient.id] || [];
			return;
		}
		try {
			const [hist, notes, insights, code, details, meds] = await Promise.allSettled([
				getWellnessHistory(patient.id), getCareNotes(patient.id), getAiInsights(patient.id),
				getPatientJoinCode(patient.id), getPatientDetails(patient.id), getMedications(patient.id)
			]);
			wellnessHistory = hist.value?.checkins || hist.value?.history || [];
			careNotes = notes.value?.notes || notes.value || [];
			aiInsights = insights.value?.insights || insights.value || [];
			patientJoinCode = code.value?.code || null;
			patientDetails = details.value?.details || null;
			caregiverMeds = meds.value?.medications || meds.value || [];
		} catch (e) { console.error(e); }
	}

	// ─── Handlers ─────────────────────────────────────────────────────────────
	async function handlePatientToggle(patient) {
		if (expandedPatientId === patient.id) {
			expandedPatientId = null; selectedPatient = null; activeTab = 'all_patients';
		} else {
			expandedPatientId = patient.id;
			await selectPatient(patient);
		}
	}

	async function handleAcknowledge(alertId) {
		if (DEMO_MODE) {
			alerts = alerts.map(a => a.id === alertId ? { ...a, is_acknowledged: 1 } : a);
			addNotification('Alert acknowledged.', 'success');
			return;
		}
		try { await acknowledgeAlert(alertId); alerts = alerts.map(a => a.id === alertId ? { ...a, is_acknowledged: 1 } : a); }
		catch (e) { addNotification('Failed to acknowledge alert', 'error'); }
	}

	async function handleGenerateOverview() {
		if (!selectedPatient) return;
		generatingOverview = true;
		if (DEMO_MODE) {
			await new Promise(r => setTimeout(r, 1800));
			aiOverview = DEMO_AI_OVERVIEWS[selectedPatient.id] || 'No overview available for this patient.';
			generatingOverview = false;
			return;
		}
		try { const result = await getAiOverview(selectedPatient.id); aiOverview = result.overview; }
		catch (e) { addNotification(e.message || 'Failed to generate overview', 'error'); }
		finally { generatingOverview = false; }
	}

	async function handleCheckin() {
		if (!selectedPatient) return;
		submittingCheckin = true;
		if (DEMO_MODE) {
			await new Promise(r => setTimeout(r, 600));
			const e = checkin.energy, f = checkin.fatigue, p = checkin.pain, m = checkin.mood,
				  s = checkin.appetite, h = checkin.hydration;
			const score = Math.min(100, Math.max(0, Math.round(((e + (11-f) + (11-p) + m + s + h) / 6) * 10)));
			const newEntry = { id: Date.now(), patient_id: selectedPatient.id, date: new Date().toISOString().split('T')[0], ...checkin, sleep_quality: 5, breathing: 5, mobility: 5, balance: 5, speech_clarity: 5, swallowing_difficulty: 5, weight: null, created_at: new Date().toISOString() };
			wellnessHistory = [newEntry, ...wellnessHistory];
			selectedPatient = { ...selectedPatient, wellness_score: score };
			patients = patients.map(p => p.id === selectedPatient.id ? selectedPatient : p).sort((a, b) => a.wellness_score - b.wellness_score);
			addNotification('Check-in submitted! (Demo)', 'success');
			checkin = { ...EMPTY_CHECKIN };
			activeTab = 'overview';
			submittingCheckin = false;
			return;
		}
		try {
			const result = await submitWellnessCheckin({
				patientId: selectedPatient.id,
				...checkin,
				weight: checkin.weight === '' || checkin.weight == null ? null : parseFloat(checkin.weight)
			});
			selectedPatient = { ...selectedPatient, wellness_score: result.wellnessScore || selectedPatient.wellness_score };
			patients = patients.map(p => p.id === selectedPatient.id ? selectedPatient : p).sort((a, b) => (a.wellness_score || 0) - (b.wellness_score || 0));
			const h = await getWellnessHistory(selectedPatient.id); wellnessHistory = h?.checkins || h?.history || [];
			addNotification('Check-in submitted!', 'success');
			checkin = { ...EMPTY_CHECKIN };
			activeTab = 'overview';
		} catch (e) { addNotification(e.message, 'error'); } finally { submittingCheckin = false; }
	}

	async function handleAddNote() {
		if (!selectedPatient || !newNote.content.trim()) return;
		submittingNote = true;
		if (DEMO_MODE) {
			await new Promise(r => setTimeout(r, 400));
			careNotes = [{ id: Date.now(), note_type: newNote.note_type, content: newNote.content, created_at: new Date().toISOString() }, ...careNotes];
			addNotification('Care note added. (Demo)', 'success');
			newNote = { content: '', note_type: 'observation' };
			submittingNote = false;
			return;
		}
		try {
			await createCareNote({ patientId: selectedPatient.id, ...newNote, caregiverId: user?.id });
			addNotification('Care note added.', 'success');
			newNote = { content: '', note_type: 'observation' };
			const n = await getCareNotes(selectedPatient.id);
			careNotes = n?.notes || n || [];
		} catch (e) { addNotification(e.message, 'error'); } finally { submittingNote = false; }
	}

	async function handleAddMedication() {
		if (!selectedPatient || !newMed.name.trim()) return;
		submittingMed = true;
		if (DEMO_MODE) {
			await new Promise(r => setTimeout(r, 400));
			caregiverMeds = [{ id: Date.now(), name: newMed.name, dosage: newMed.dosage, frequency: newMed.frequency, is_active: 1 }, ...caregiverMeds];
			addNotification('Medication added. (Demo)', 'success');
			newMed = { name: '', dosage: '', frequency: '' };
			submittingMed = false;
			return;
		}
		try {
			await createMedication({ patientId: selectedPatient.id, ...newMed });
			addNotification('Medication added.', 'success');
			newMed = { name: '', dosage: '', frequency: '' };
			const m = await getMedications(selectedPatient.id);
			caregiverMeds = m?.medications || m || [];
		} catch (e) { addNotification(e.message, 'error'); } finally { submittingMed = false; }
	}

	async function handleFamilyLink() {
		if (!familyJoinCodeInput.trim()) return;
		linkingCode = true;
		if (DEMO_MODE) {
			await new Promise(r => setTimeout(r, 600));
			const match = Object.entries(DEMO_JOIN_CODES).find(([, code]) => code === familyJoinCodeInput.trim().toUpperCase());
			if (match) {
				const pid = Number(match[0]);
				linkedPatient = DEMO_PATIENTS.find(p => p.id === pid) || null;
				familyLinked = true;
				familyWellness = DEMO_WELLNESS[pid] || [];
				familyMeds = DEMO_MEDS[pid] || [];
				familyNotes = DEMO_NOTES[pid] || [];
				addNotification(`Linked to ${linkedPatient?.first_name}! (Demo)`, 'success');
			} else {
				addNotification('Invalid join code. Try MCH001, ROK002, or ELV003.', 'error');
			}
			linkingCode = false;
			return;
		}
		try {
			const result = await familyLink(familyJoinCodeInput.trim().toUpperCase());
			if (result.patient) { linkedPatient = result.patient; familyLinked = true; await loadFamilyData(); addNotification(`Linked to ${result.patient.first_name}!`, 'success'); }
		} catch (e) { addNotification(e.message || 'Invalid join code', 'error'); } finally { linkingCode = false; }
	}

	function handleLogout() {
		if (!DEMO_MODE) auth.logout();
		goto('/login');
	}

	// ─── Physical details editing ─────────────────────────────────────────────
	let editingPhysical = false;
	let savingPhysical = false;
	let physicalForm = {};

	function startEditPhysical() {
		physicalForm = {
			gender: patientDetails?.gender || '',
			height_cm: patientDetails?.height_cm != null ? String(patientDetails.height_cm) : '',
			weight_kg: patientDetails?.weight_kg != null ? String(patientDetails.weight_kg) : '',
			vision_score: patientDetails?.vision_score || '',
			hearing_notes: patientDetails?.hearing_notes || '',
			medical_history: patientDetails?.medical_history || '',
			diagnoses: Array.isArray(patientDetails?.diagnoses) ? patientDetails.diagnoses.join(', ') : '',
			allergies: Array.isArray(patientDetails?.allergies) ? patientDetails.allergies.join(', ') : '',
			ai_companion_name: patientDetails?.ai_companion_name || ''
		};
		editingPhysical = true;
	}

	async function savePhysicalDetails() {
		if (!selectedPatient) return;
		savingPhysical = true;
		const parsed = {
			gender: physicalForm.gender || null,
			height_cm: physicalForm.height_cm ? parseFloat(physicalForm.height_cm) : null,
			weight_kg: physicalForm.weight_kg ? parseFloat(physicalForm.weight_kg) : null,
			vision_score: physicalForm.vision_score || null,
			hearing_notes: physicalForm.hearing_notes || null,
			medical_history: physicalForm.medical_history || null,
			diagnoses: physicalForm.diagnoses ? physicalForm.diagnoses.split(',').map(s => s.trim()).filter(Boolean) : [],
			allergies: physicalForm.allergies ? physicalForm.allergies.split(',').map(s => s.trim()).filter(Boolean) : [],
			ai_companion_name: physicalForm.ai_companion_name || null
		};
		if (DEMO_MODE) {
			await new Promise(r => setTimeout(r, 450));
			patientDetails = { ...patientDetails, ...parsed };
			addNotification('Physical details saved. (Demo)', 'success');
			editingPhysical = false;
			savingPhysical = false;
			return;
		}
		try {
			await fetch(`/api/patients/${selectedPatient.id}/details`, {
				method: 'PATCH',
				headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${$auth.token}` },
				body: JSON.stringify({ gender: parsed.gender, heightCm: parsed.height_cm, weightKg: parsed.weight_kg,
					hearingNotes: parsed.hearing_notes, visionScore: parsed.vision_score, medicalHistory: parsed.medical_history,
					diagnoses: parsed.diagnoses, allergies: parsed.allergies, aiCompanionName: parsed.ai_companion_name })
			});
			patientDetails = { ...patientDetails, ...parsed };
			addNotification('Physical details saved.', 'success');
			editingPhysical = false;
		} catch (e) { addNotification('Failed to save details.', 'error'); }
		finally { savingPhysical = false; }
	}

	function copyToClipboard(text) {
		navigator.clipboard.writeText(text).then(() => addNotification('Copied!', 'success'));
	}

	function getScoreColor(score) {
		if (score >= 80) return '#10b981';
		if (score >= 60) return '#f59e0b';
		return '#ef4444';
	}

	function getScoreLabel(score) {
		if (score >= 80) return 'Excellent';
		if (score >= 60) return 'Moderate';
		return 'Needs Attention';
	}

	function formatDate(dateStr) {
		if (!dateStr) return '—';
		return new Date(dateStr).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
	}

	$: pendingAlerts = alerts.filter(a => !a.is_acknowledged);
	$: initials = selectedPatient
		? `${selectedPatient.first_name?.[0] || ''}${selectedPatient.last_name?.[0] || ''}`.toUpperCase() || '?'
		: '';
</script>

<svelte:head>
	<title>Dashboard — CareBridge</title>
</svelte:head>

{#if loading}
	<div class="loading-full">
		<div class="loading-spinner"></div>
		<p>Loading…</p>
	</div>

<!-- ══ PATIENT: app-only page ══════════════════════════════════════════════ -->
{:else if user?.role === 'patient'}
	<div class="portal-page">
		<header class="portal-header">
			<div class="portal-brand">
				<img src="/logo.png" alt="CareBridge" class="portal-logo" />
				<span class="portal-brand-name">CareBridge</span>
			</div>
			<button class="btn btn-secondary signout-btn" on:click={handleLogout}>
				<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
					<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>
					<polyline points="16 17 21 12 16 7"/>
					<line x1="21" y1="12" x2="9" y2="12"/>
				</svg>
				Sign Out
			</button>
		</header>
		<div class="portal-body">
			<div class="app-only-card">
				<div class="app-icon-wrap">
					<img src="/logo.png" alt="CareBridge" class="app-icon" />
				</div>
				<h2>CareBridge is on your phone</h2>
				<p>Your wellness journey is designed for the mobile app. Check in, view your journal, track medications, and stay connected with your care team — all from the CareBridge iOS app.</p>
				<div class="app-badge-row">
					<div class="app-store-badge">
						<svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/></svg>
						App Store
					</div>
				</div>
				<p class="portal-user-note">Signed in as {user?.firstName || user?.email}</p>
			</div>
		</div>
	</div>

<!-- ══ FAMILY: family portal ═══════════════════════════════════════════════ -->
{:else if user?.role === 'family'}
	<div class="portal-page">
		<header class="portal-header">
			<div class="portal-brand">
				<img src="/logo.png" alt="CareBridge" class="portal-logo" />
				<span class="portal-brand-name">CareBridge</span>
				{#if familyLinked && linkedPatient}
					<span class="family-viewing-badge">
						Viewing: {linkedPatient.first_name} {linkedPatient.last_name || ''}
					</span>
				{/if}
			</div>
			<button class="btn btn-secondary signout-btn" on:click={handleLogout}>
				<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
					<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>
					<polyline points="16 17 21 12 16 7"/>
					<line x1="21" y1="12" x2="9" y2="12"/>
				</svg>
				Sign Out
			</button>
		</header>

		<div class="portal-body">
			{#if !familyLinked}
				<!-- Not linked yet — show join code entry -->
				<div class="join-code-gate">
					<div class="join-icon">
						<svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="#3b82f6" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
							<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/>
							<path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>
						</svg>
					</div>
					<h2>Connect to your family member</h2>
					<p>Enter the 6-character join code provided by your family member's care team to view their health updates.</p>
					<div class="code-input-row">
						<input
							type="text"
							bind:value={familyJoinCodeInput}
							placeholder="e.g. A3F2B1"
							maxlength="6"
							style="text-transform:uppercase; letter-spacing: 0.15em; font-size: 1.1rem;"
							on:keydown={e => e.key === 'Enter' && handleFamilyLink()}
						/>
						<button class="btn btn-primary" on:click={handleFamilyLink} disabled={linkingCode || !familyJoinCodeInput.trim()}>
							{linkingCode ? 'Linking…' : 'Connect'}
						</button>
					</div>
				</div>
			{:else}
				<!-- Linked — show patient dashboard -->
				<div class="family-dashboard">
					<!-- Patient summary card -->
					<div class="patient-summary-card card">
						<div class="patient-summary-left">
							<div class="patient-avatar-lg" style="background: {getScoreColor(linkedPatient.wellness_score)}">
								{linkedPatient.first_name?.[0] || '?'}{linkedPatient.last_name?.[0] || ''}
							</div>
							<div>
								<h2 class="patient-name-lg">{linkedPatient.first_name} {linkedPatient.last_name || ''}</h2>
								<span class="badge badge-{linkedPatient.wellness_score >= 80 ? 'success' : linkedPatient.wellness_score >= 60 ? 'warning' : 'danger'}">
									{getScoreLabel(linkedPatient.wellness_score)}
								</span>
							</div>
						</div>
						<div class="patient-score-block">
							<div class="score-circle" style="--c: {getScoreColor(linkedPatient.wellness_score)}">
								<span style="color: {getScoreColor(linkedPatient.wellness_score)}">{linkedPatient.wellness_score || '—'}</span>
							</div>
							<span class="score-circle-label">Wellness Score</span>
						</div>
					</div>

					<!-- Tabs -->
					<div class="family-tabs">
						{#each [['overview','Overview'],['meds','Medications'],['notes','Care Notes']] as [t, l]}
							<button class="family-tab {familyTab === t ? 'active' : ''}" on:click={() => familyTab = t}>{l}</button>
						{/each}
					</div>

					{#if familyTab === 'overview'}
						<div class="fade-in">
							{#if familyWellness.length > 0}
								<div class="card">
									<div class="card-header"><span class="card-title">Recent Check-ins</span></div>
									<div class="checkin-table">
										<div class="table-head family-table-head">
											<span>Date</span><span>Energy</span><span>Mood</span><span>Pain</span><span>Notes</span>
										</div>
										{#each familyWellness.slice(0, 5) as entry}
											<div class="table-row family-table-row">
												<span>{formatDate(entry.created_at || entry.date)}</span>
												<span class="metric-chip">{entry.energy ?? '—'}</span>
												<span class="metric-chip">{entry.mood ?? '—'}</span>
												<span class="metric-chip" style="{(entry.pain||0) >= 7 ? 'color:#ef4444' : ''}">{entry.pain ?? '—'}</span>
												<span class="note-preview">{entry.notes || '—'}</span>
											</div>
										{/each}
									</div>
								</div>
							{:else}
								<div class="card empty-card">No wellness check-ins recorded yet.</div>
							{/if}
						</div>

					{:else if familyTab === 'meds'}
						<div class="fade-in">
							{#if familyMeds.filter(m => m.is_active).length > 0}
								<div class="meds-grid">
									{#each familyMeds.filter(m => m.is_active) as med}
										<div class="med-card card">
											<div class="med-name">{med.name}</div>
											<div class="med-detail">{med.dosage || '—'} · {med.frequency || '—'}</div>
											{#if med.instructions}<p class="med-note">{med.instructions}</p>{/if}
										</div>
									{/each}
								</div>
							{:else}
								<div class="card empty-card">No active medications on record.</div>
							{/if}
						</div>

					{:else if familyTab === 'notes'}
						<div class="fade-in">
							{#if familyNotes.length > 0}
								<div class="notes-list">
									{#each familyNotes.slice(0, 10) as note (note.id)}
										<div class="note-card card">
											<div class="note-header">
												<span class="badge badge-info">{note.note_type || 'observation'}</span>
												<span class="note-date">{formatDate(note.created_at)}</span>
											</div>
											<p class="note-content">{note.content}</p>
										</div>
									{/each}
								</div>
							{:else}
								<div class="card empty-card">No care notes yet.</div>
							{/if}
						</div>
					{/if}
				</div>
			{/if}
		</div>
	</div>

<!-- ══ CAREGIVER / ORGANIZATION: full dashboard ════════════════════════════ -->
{:else}
	<div class="app-shell">
		<!-- Sidebar -->
		<aside class="sidebar" class:collapsed={sidebarCollapsed}>
			<div class="sidebar-header">
				{#if !sidebarCollapsed}
					<div class="brand">
						<img src="/logo.png" alt="CareBridge" class="brand-logo" />
						<span class="brand-name">CareBridge</span>
					</div>
				{/if}
				<button class="collapse-btn" on:click={() => sidebarCollapsed = !sidebarCollapsed} aria-label="Toggle sidebar">
					{#if sidebarCollapsed}
						<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"/></svg>
					{:else}
						<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"/></svg>
					{/if}
				</button>
			</div>

			<!-- Nav -->
			<nav class="sidebar-nav">
				<button
					class="nav-item {activeTab === 'all_patients' && !selectedPatient ? 'active' : ''}"
					on:click={() => { selectedPatient = null; expandedPatientId = null; activeTab = 'all_patients'; }}
					title={sidebarCollapsed ? 'All Patients' : undefined}
				>
					<span class="nav-icon">
						<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
					</span>
					{#if !sidebarCollapsed}<span class="nav-label">All Patients</span>{/if}
				</button>
			</nav>

			<!-- Patient accordion list -->
			{#if !sidebarCollapsed}
				<div class="sidebar-section">
					<div class="section-label">Patients</div>
					<div class="patient-list">
						{#each patients as patient (patient.id)}
							<div class="patient-accordion">
								<button
									class="patient-item {expandedPatientId === patient.id ? 'selected' : ''}"
									on:click={() => handlePatientToggle(patient)}
								>
									<div class="patient-avatar-sm" style="background: {getScoreColor(patient.wellness_score)}">
										{patient.first_name?.[0] || patient.email?.[0] || '?'}
									</div>
									<div class="patient-meta">
										<span class="patient-name-sm">{patient.first_name} {patient.last_name || ''}</span>
										<span class="patient-score-sm" style="color: {getScoreColor(patient.wellness_score)}">{patient.wellness_score || '—'}</span>
									</div>
									<svg class="patient-chevron {expandedPatientId === patient.id ? 'open' : ''}" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 12 15 18 9"/></svg>
								</button>
								{#if expandedPatientId === patient.id}
									<div class="patient-subnav">
										{#each [
											{ id: 'overview', label: 'Overview' },
											{ id: 'ai_overview', label: 'AI Overview' },
											{ id: 'checkin', label: 'Wellness Check-in' },
											{ id: 'meds', label: 'Medications' },
											{ id: 'notes', label: 'Care Notes' },
											{ id: 'insights', label: 'AI Insights' },
											{ id: 'physical', label: 'Physical Details' },
											{ id: 'family', label: 'Family' }
										] as sub}
											<button
												class="subnav-item {activeTab === sub.id ? 'active' : ''}"
												on:click={() => activeTab = sub.id}
											>{sub.label}</button>
										{/each}
									</div>
								{/if}
							</div>
						{/each}
						{#if patients.length === 0}
							<p class="no-patients">No patients yet</p>
						{/if}
					</div>
				</div>
			{/if}

			<!-- User -->
			<div class="sidebar-footer">
				<div class="user-info">
					<div class="user-avatar">{user?.firstName?.[0] || user?.email?.[0] || 'U'}</div>
					{#if !sidebarCollapsed}
						<div class="user-details">
							<span class="user-name">{user?.firstName || user?.email}</span>
							<span class="user-role">{user?.role || 'Caregiver'}</span>
						</div>
						<button class="logout-btn" on:click={handleLogout} id="logout-btn">
							<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
								<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>
								<polyline points="16 17 21 12 16 7"/>
								<line x1="21" y1="12" x2="9" y2="12"/>
							</svg>
							Sign Out
						</button>
					{/if}
				</div>
			</div>
		</aside>

		<!-- Main -->
		<main class="main" class:collapsed={sidebarCollapsed}>
			<!-- Page header -->
			<header class="page-header">
				<div>
					<h1>
						{activeTab === 'all_patients' ? 'All Patients' :
						 activeTab === 'overview' ? 'Patient Overview' :
						 activeTab === 'ai_overview' ? 'AI Overview' :
						 activeTab === 'checkin' ? 'Wellness Check-In' :
						 activeTab === 'meds' ? 'Medications' :
						 activeTab === 'notes' ? 'Care Notes' :
						 activeTab === 'insights' ? 'AI Insights' :
						 activeTab === 'physical' ? 'Physical Details' :
						 activeTab === 'family' ? 'Family & Contacts' : 'Dashboard'}
					</h1>
					{#if selectedPatient && activeTab !== 'all_patients'}
						<p class="page-subtitle">
							{selectedPatient.first_name} {selectedPatient.last_name || ''} · Updated {formatDate(selectedPatient.updated_at)}
						</p>
					{/if}
				</div>
				{#if selectedPatient && activeTab !== 'all_patients'}
					<div class="header-patient-badge">
						<div class="avatar-md" style="background: {getScoreColor(selectedPatient.wellness_score)}">{initials}</div>
						<div>
							<div class="score-value" style="color: {getScoreColor(selectedPatient.wellness_score)}">{selectedPatient.wellness_score || '—'}</div>
							<div class="score-sublabel">{getScoreLabel(selectedPatient.wellness_score)}</div>
						</div>
					</div>
				{/if}
			</header>

			<!-- ── All Patients ── -->
			{#if activeTab === 'all_patients'}
				<div class="fade-in">
					<!-- Organization -->
					{#if organization}
						<div class="org-card">
							<div class="org-card-main">
								<div class="org-badge">{(organization.name || 'O').charAt(0).toUpperCase()}</div>
								<div>
									<div class="org-name">{organization.name}</div>
									<div class="org-meta">{organization.patient_count} patient{organization.patient_count === 1 ? '' : 's'} · {organization.member_count} member{organization.member_count === 1 ? '' : 's'}</div>
								</div>
							</div>
							<div class="org-code-box">
								<span class="org-code-label">Join code</span>
								<span class="org-code">{organization.join_code}</span>
								<button class="btn btn-sm btn-secondary" on:click={() => copyToClipboard(organization.join_code)}>Copy</button>
							</div>
						</div>
					{:else}
						<div class="org-card org-setup">
							<div class="org-setup-col">
								<div class="org-setup-title">Create an organization</div>
								<p class="org-setup-sub">Name it and get a join code to share with your patients and caregivers.</p>
								<div class="org-setup-row">
									<input type="text" placeholder="Organization name" bind:value={orgNameInput} />
									<button class="btn btn-primary btn-sm" on:click={handleCreateOrg} disabled={orgBusy || !orgNameInput.trim()}>Create</button>
								</div>
							</div>
							<div class="org-setup-divider"></div>
							<div class="org-setup-col">
								<div class="org-setup-title">Join an organization</div>
								<p class="org-setup-sub">Enter a code you were given.</p>
								<div class="org-setup-row">
									<input type="text" placeholder="Join code" bind:value={orgCodeInput} />
									<button class="btn btn-secondary btn-sm" on:click={handleJoinOrg} disabled={orgBusy || !orgCodeInput.trim()}>Join</button>
								</div>
							</div>
						</div>
					{/if}

					<!-- Alerts panel -->
					{#if pendingAlerts.length > 0}
						<div class="alerts-panel">
							<div class="alerts-panel-header">
								<div class="alerts-panel-title">
									<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg>
									Patient Alerts
								</div>
								<span class="alerts-count">{pendingAlerts.length} pending</span>
							</div>
							{#each pendingAlerts as alert (alert.id)}
								<div class="alert-row" class:urgent={alert.is_urgent}>
									<div class="alert-info">
										{#if alert.is_urgent}
											<span class="badge badge-danger">Urgent</span>
										{:else}
											<span class="badge badge-warning">Call Request</span>
										{/if}
										<span class="alert-patient">{alert.patient_name}</span>
										<span class="alert-msg">{alert.message}</span>
										<span class="alert-time">{formatDate(alert.created_at)}</span>
									</div>
									<button class="btn btn-sm btn-secondary" on:click={() => handleAcknowledge(alert.id)}>
										Acknowledge
									</button>
								</div>
							{/each}
						</div>
					{/if}

					<div class="card">
						<div class="card-header"><span class="card-title">Patient Roster</span></div>
						<div class="checkin-table">
							<div class="table-head roster-head">
								<span>Patient</span><span>Status</span><span>Wellness</span><span>Attention</span><span></span>
							</div>
							{#each patients as p}
								<div class="table-row roster-row">
									<span><strong>{p.first_name} {p.last_name || ''}</strong></span>
									<span class="badge badge-{p.wellness_score >= 80 ? 'success' : p.wellness_score >= 60 ? 'warning' : 'danger'}">{getScoreLabel(p.wellness_score)}</span>
									<span class="metric-chip" style="color: {getScoreColor(p.wellness_score)}">{p.wellness_score || '—'}</span>
									<span>
										{#if (p.wellness_score || 100) < 60}
											<span class="badge badge-danger">Needs Contact</span>
										{:else}
											<span class="text-muted">Up to date</span>
										{/if}
									</span>
									<span>
										<button class="btn btn-sm btn-secondary" on:click={() => selectPatient(p)}>View</button>
									</span>
								</div>
							{/each}
							{#if patients.length === 0}
								<div class="empty-row">No patients found. Register a patient account to get started.</div>
							{/if}
						</div>
					</div>
				</div>

			<!-- ── Overview ── -->
			{:else if activeTab === 'overview'}
				<div class="fade-in">
					{#if !selectedPatient}
						<div class="empty-state card">
							<div class="empty-icon">
								<svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="#94a3b8" stroke-width="1.5"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/></svg>
							</div>
							<h3>Select a patient</h3>
							<p>Choose a patient from the sidebar or the All Patients list.</p>
						</div>
					{:else}
						<div class="stats-row">
							{#each [
								{ label: 'Check-ins', value: wellnessHistory.length, color: '#3b82f6' },
								{ label: 'Care Notes', value: careNotes.length, color: '#8b5cf6' },
								{ label: 'AI Insights', value: aiInsights.length, color: '#14b8a6' }
							] as stat}
								<div class="stat-card card">
									<div class="stat-value" style="color: {stat.color}">{stat.value}</div>
									<div class="stat-label">{stat.label}</div>
								</div>
							{/each}
						</div>

						<!-- Wellness score -->
						<div class="card">
							<div class="card-header">
								<span class="card-title">Wellness Score</span>
								<span class="badge badge-{selectedPatient.wellness_score >= 80 ? 'success' : selectedPatient.wellness_score >= 60 ? 'warning' : 'danger'}">
									{getScoreLabel(selectedPatient.wellness_score)}
								</span>
							</div>
							<div class="score-display">
								<div class="score-ring" style="--score: {selectedPatient.wellness_score || 0}; --color: {getScoreColor(selectedPatient.wellness_score)}">
									<span class="score-number" style="color: {getScoreColor(selectedPatient.wellness_score)}">{selectedPatient.wellness_score || 0}</span>
								</div>
								<div class="score-bar-wrapper">
									<div class="score-track">
										<div class="score-fill" style="width: {selectedPatient.wellness_score || 0}%; background: {getScoreColor(selectedPatient.wellness_score)}"></div>
									</div>
									<div class="score-markers"><span>0</span><span>Critical</span><span>Moderate</span><span>Excellent</span><span>100</span></div>
								</div>
							</div>
						</div>

						<!-- AI Handoff Overview -->
						<div class="card ai-overview-card">
							<div class="card-header">
								<span class="card-title">AI Handoff Overview</span>
								<button class="btn btn-sm btn-primary" on:click={handleGenerateOverview} disabled={generatingOverview}>
									{#if generatingOverview}
										<span class="mini-spinner"></span> Generating…
									{:else}
										<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
										Generate
									{/if}
								</button>
							</div>
							{#if aiOverview}
								<p class="ai-overview-text">{aiOverview}</p>
							{:else}
								<p class="ai-overview-empty">Click Generate to create a clinical handoff summary powered by AI — based on this patient's wellness history, medications, and care notes.</p>
							{/if}
						</div>

						<!-- Recent check-ins -->
						{#if wellnessHistory.length > 0}
							<div class="card">
								<div class="card-header">
									<span class="card-title">Recent Check-ins</span>
									<button class="btn btn-sm btn-secondary" on:click={() => activeTab = 'checkin'}>+ New</button>
								</div>
								<div class="checkin-table">
									<div class="table-head"><span>Date</span><span>Energy</span><span>Mood</span><span>Pain</span><span>Notes</span></div>
									{#each wellnessHistory.slice(0, 5) as entry}
										<div class="table-row">
											<span>{formatDate(entry.created_at || entry.date)}</span>
											<span class="metric-chip">{entry.energy ?? '—'}</span>
											<span class="metric-chip">{entry.mood ?? '—'}</span>
											<span class="metric-chip" style="{(entry.pain||0) >= 7 ? 'color:#ef4444' : ''}">{entry.pain ?? '—'}</span>
											<span class="note-preview">{entry.notes || '—'}</span>
										</div>
									{/each}
								</div>
							</div>
						{:else}
							<div class="card empty-card">
								<span>No check-ins yet.</span>
								<button class="btn btn-primary btn-sm" on:click={() => activeTab = 'checkin'}>Submit first check-in</button>
							</div>
						{/if}
					{/if}
				</div>

			<!-- ── Check-in ── -->
			{:else if activeTab === 'checkin'}
				<div class="card fade-in">
					<div class="card-header">
						<span class="card-title">Daily Wellness Check-In</span>
						<span class="text-muted">Tracking {selectedPatient?.first_name || 'patient'}</span>
					</div>
					<div class="sliders-grid">
						{#each [
							{ key: 'energy', label: 'Energy', icon: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/></svg>`, color: '#f59e0b', lowLabel: 'Exhausted', highLabel: 'Energized' },
							{ key: 'fatigue', label: 'Fatigue', icon: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.79A9 9 0 1111.21 3 7 7 0 0021 12.79z"/></svg>`, color: '#6366f1', lowLabel: 'Alert', highLabel: 'Exhausted' },
							{ key: 'pain', label: 'Pain Level', icon: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>`, color: '#ef4444', lowLabel: 'No Pain', highLabel: 'Severe' },
							{ key: 'mood', label: 'Mood', icon: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="M8 14s1.5 2 4 2 4-2 4-2"/><line x1="9" y1="9" x2="9.01" y2="9"/><line x1="15" y1="9" x2="15.01" y2="9"/></svg>`, color: '#10b981', lowLabel: 'Very Low', highLabel: 'Great' },
							{ key: 'sleepQuality', label: 'Sleep Quality', icon: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.79A9 9 0 1111.21 3 7 7 0 0021 12.79z"/></svg>`, color: '#8b5cf6', lowLabel: 'Poor', highLabel: 'Restful' },
							{ key: 'breathing', label: 'Breathing', icon: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9.59 4.59A2 2 0 1111 8H2m10.59 11.41A2 2 0 1014 16H2m15.73-8.27A2.5 2.5 0 1119.5 12H2"/></svg>`, color: '#3b82f6', lowLabel: 'Labored', highLabel: 'Easy' },
							{ key: 'mobility', label: 'Mobility', icon: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="13" cy="4" r="1"/><path d="M4 17l5-1 2-4 4 3 3-1M9 12l1-4 4 1 2 3"/></svg>`, color: '#f97316', lowLabel: 'Limited', highLabel: 'Full' },
							{ key: 'balance', label: 'Balance', icon: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="4" r="1.5"/><path d="M12 6v7m-4 8l4-8 4 8M6 9h12"/></svg>`, color: '#14b8a6', lowLabel: 'Unsteady', highLabel: 'Steady' },
							{ key: 'speechClarity', label: 'Speech Clarity', icon: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z"/></svg>`, color: '#6366f1', lowLabel: 'Unclear', highLabel: 'Clear' },
							{ key: 'appetite', label: 'Appetite', icon: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8h1a4 4 0 010 8h-1"/><path d="M2 8h16v9a4 4 0 01-4 4H6a4 4 0 01-4-4V8z"/><line x1="6" y1="1" x2="6" y2="4"/><line x1="10" y1="1" x2="10" y2="4"/><line x1="14" y1="1" x2="14" y2="4"/></svg>`, color: '#f97316', lowLabel: 'None', highLabel: 'Normal' },
							{ key: 'hydration', label: 'Hydration', icon: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2.69l5.66 5.66a8 8 0 11-11.31 0z"/></svg>`, color: '#06b6d4', lowLabel: 'Dehydrated', highLabel: 'Well-hydrated' },
							{ key: 'swallowingDifficulty', label: 'Swallowing', icon: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2a3 3 0 013 3v6a3 3 0 01-6 0V5a3 3 0 013-3z"/><path d="M12 17v4"/></svg>`, color: '#e11d48', lowLabel: 'Easy', highLabel: 'Difficult' }
						] as slider}
							<div class="slider-card">
								<div class="slider-header">
									<span class="slider-icon" style="color: {slider.color}">{@html slider.icon}</span>
									<span class="slider-name">{slider.label}</span>
									<span class="slider-val">{checkin[slider.key]}</span>
								</div>
								<input type="range" min="1" max="10" bind:value={checkin[slider.key]} class="range-input" />
								<div class="slider-labels"><span>{slider.lowLabel}</span><span>{slider.highLabel}</span></div>
							</div>
						{/each}
					</div>
					<div class="form-group" style="margin-top: 24px;">
						<label for="checkin-weight">Weight (kg) <span class="text-muted" style="font-weight:400">— optional</span></label>
						<input id="checkin-weight" type="number" inputmode="decimal" step="0.1" min="0" bind:value={checkin.weight} placeholder="e.g. 68.5" />
					</div>
					<div class="form-group" style="margin-top: 24px;">
						<label for="checkin-notes">Additional Notes</label>
						<textarea id="checkin-notes" bind:value={checkin.notes} placeholder="Any observations, concerns, or context…" rows="3"></textarea>
					</div>
					<button class="btn btn-primary" on:click={handleCheckin} disabled={submittingCheckin || !selectedPatient} id="submit-checkin-btn">
						{#if submittingCheckin}<span class="mini-spinner"></span> Submitting…{:else}<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="width:16px;height:16px;vertical-align:middle;margin-right:6px"><polyline points="20 6 9 17 4 12"/></svg>Submit Check-In{/if}
					</button>
				</div>

			<!-- ── Medications ── -->
			{:else if activeTab === 'meds'}
				<div class="fade-in">
					<div class="card">
						<div class="card-header">
							<span class="card-title">Add Medication</span>
						</div>
						<div class="form-row" style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 12px; margin-bottom: 16px;">
							<div class="form-group" style="margin: 0;">
								<label for="med-name">Medication Name</label>
								<input id="med-name" type="text" bind:value={newMed.name} placeholder="e.g. Metformin" />
							</div>
							<div class="form-group" style="margin: 0;">
								<label for="med-dosage">Dosage</label>
								<input id="med-dosage" type="text" bind:value={newMed.dosage} placeholder="e.g. 500mg" />
							</div>
							<div class="form-group" style="margin: 0;">
								<label for="med-frequency">Frequency</label>
								<input id="med-frequency" type="text" bind:value={newMed.frequency} placeholder="e.g. Twice daily" />
							</div>
						</div>
						<button class="btn btn-primary" on:click={handleAddMedication} disabled={submittingMed || !newMed.name.trim() || !selectedPatient}>
							{submittingMed ? 'Adding…' : '+ Add Medication'}
						</button>
					</div>

					{#if caregiverMeds.length > 0}
						<div class="meds-list" style="margin-top: 1.5rem; display: flex; flex-direction: column; gap: 10px;">
							{#each caregiverMeds as med (med.id)}
								<div class="med-card card" style="display: flex; align-items: center; gap: 16px; padding: 16px 20px;">
									<div class="med-icon" style="width: 40px; height: 40px; border-radius: 10px; background: rgba(59,130,246,0.1); display: flex; align-items: center; justify-content: center; flex-shrink: 0;">
										<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#3b82f6" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.5 20H4a2 2 0 0 1-2-2V5c0-1.1.9-2 2-2h3.93a2 2 0 0 1 1.66.9l.82 1.2a2 2 0 0 0 1.66.9H20a2 2 0 0 1 2 2v3"/><circle cx="18" cy="18" r="3"/><path d="M22 22l-1.5-1.5"/></svg>
									</div>
									<div style="flex: 1; min-width: 0;">
										<div style="font-weight: 600; font-size: 0.95rem;">{med.name}</div>
										<div style="font-size: 0.82rem; color: var(--text-muted); margin-top: 2px;">
											{[med.dosage, med.frequency].filter(Boolean).join(' · ') || 'No details'}
										</div>
									</div>
									<span class="badge badge-{med.is_active ? 'success' : 'warning'}" style="flex-shrink: 0;">
										{med.is_active ? 'Active' : 'Inactive'}
									</span>
								</div>
							{/each}
						</div>
					{:else}
						<div class="card empty-card" style="margin-top: 1.5rem;">No medications recorded for this patient.</div>
					{/if}
				</div>

			<!-- ── Care Notes ── -->
			{:else if activeTab === 'notes'}
				<div class="fade-in">
					<div class="card">
						<div class="card-header"><span class="card-title">Add Care Note</span></div>
						<div class="form-group">
							<label for="note-type">Note Type</label>
							<CustomSelect id="note-type" bind:value={newNote.note_type} options={NOTE_TYPES.map(t => ({ value: t, label: t.charAt(0).toUpperCase() + t.slice(1) }))} />
						</div>
						<div class="form-group">
							<label for="note-content">Note</label>
							<textarea id="note-content" bind:value={newNote.content} placeholder="Describe your observation, concern, or update…" rows="4"></textarea>
						</div>
						<button class="btn btn-primary" on:click={handleAddNote} disabled={submittingNote || !newNote.content.trim()} id="add-note-btn">
							{submittingNote ? 'Saving…' : '+ Add Note'}
						</button>
					</div>
					{#if careNotes.length > 0}
						<div class="notes-list">
							{#each careNotes as note (note.id)}
								<div class="note-card card">
									<div class="note-header">
										<span class="badge badge-info">{note.note_type || 'observation'}</span>
										<span class="note-date">{formatDate(note.created_at)}</span>
									</div>
									<p class="note-content">{note.content}</p>
								</div>
							{/each}
						</div>
					{:else}
						<div class="card empty-card">No care notes yet.</div>
					{/if}
				</div>

			<!-- ── AI Overview ── -->
			{:else if activeTab === 'ai_overview'}
				<div class="fade-in">
					{#if !selectedPatient}
						<div class="empty-state card">
							<div class="empty-icon">
								<svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="#94a3b8" stroke-width="1.5"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
							</div>
							<h3>Select a patient</h3>
							<p>Choose a patient from the sidebar to generate their AI overview.</p>
						</div>
					{:else}
						<div class="card ai-overview-card ai-overview-full">
							<div class="card-header">
								<span class="card-title">AI Handoff Overview</span>
								<button class="btn btn-sm btn-primary" on:click={handleGenerateOverview} disabled={generatingOverview}>
									{#if generatingOverview}
										<span class="mini-spinner"></span> Generating…
									{:else}
										<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
										Generate
									{/if}
								</button>
							</div>
							<p class="ai-overview-meta">Powered by NVIDIA · {selectedPatient.first_name} {selectedPatient.last_name || ''}</p>
							{#if aiOverview}
								<p class="ai-overview-text">{aiOverview}</p>
							{:else}
								<p class="ai-overview-empty">Click Generate to create a clinical handoff summary — based on this patient's wellness history, medications, and care notes.</p>
							{/if}
						</div>
					{/if}
				</div>

			<!-- ── AI Insights ── -->
			{:else if activeTab === 'insights'}
				<div class="fade-in">
					{#if aiInsights.length > 0}
						<div class="insights-list">
							{#each aiInsights as insight (insight.id)}
								<div class="insight-card card">
									<div class="insight-header">
										<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#14b8a6" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
										<div>
											<h3 class="insight-title">{insight.title || 'Insight'}</h3>
											<span class="badge badge-{insight.severity === 'high' ? 'danger' : insight.severity === 'medium' ? 'warning' : 'success'}">{insight.severity || 'low'} priority</span>
										</div>
									</div>
									<p class="insight-desc">{insight.description}</p>
									<div class="insight-date">{formatDate(insight.created_at)}</div>
								</div>
							{/each}
						</div>
					{:else}
						<div class="card empty-state">
							<div class="empty-icon">
								<svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="#94a3b8" stroke-width="1.5"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
							</div>
							<h3>No AI insights yet</h3>
							<p>Insights appear after several wellness check-ins are recorded.</p>
						</div>
					{/if}
				</div>
			{/if}

			<!-- ── Physical Details ── -->
			{#if activeTab === 'physical'}
				<div class="fade-in">
					{#if !editingPhysical}
						<!-- View mode -->
						<div class="card">
							<div class="card-header">
								<span class="card-title">Physical Overview</span>
								<button class="btn btn-sm btn-secondary" on:click={startEditPhysical}>
									<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
									Edit Details
								</button>
							</div>
							<div class="metrics-grid">
								<div class="metric-box">
									<div class="metric-label">Gender</div>
									<div class="metric-val">{patientDetails?.gender ? patientDetails.gender.charAt(0).toUpperCase() + patientDetails.gender.slice(1) : '—'}</div>
								</div>
								<div class="metric-box">
									<div class="metric-label">Height</div>
									<div class="metric-val">{patientDetails?.height_cm ? `${patientDetails.height_cm} cm` : '—'}</div>
								</div>
								<div class="metric-box">
									<div class="metric-label">Weight</div>
									<div class="metric-val">{patientDetails?.weight_kg ? `${patientDetails.weight_kg} kg` : '—'}</div>
								</div>
							</div>
						</div>

						<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1.5rem; margin-top: 1.5rem;">
							<div class="card">
								<div class="card-header"><span class="card-title">Sensory</span></div>
								<div class="detail-row"><span class="detail-label">Vision</span><span class="detail-val">{patientDetails?.vision_score || '—'}</span></div>
								<div class="detail-row" style="margin-top: 10px;"><span class="detail-label">Hearing</span><span class="detail-val">{patientDetails?.hearing_notes || '—'}</span></div>
							</div>
							<div class="card">
								<div class="card-header"><span class="card-title">AI Companion</span></div>
								<div class="detail-row"><span class="detail-label">Name</span><span class="detail-val">{patientDetails?.ai_companion_name || '—'}</span></div>
								<p style="font-size: 0.8rem; color: var(--text-muted); margin-top: 8px;">Name used by the AI companion when chatting with the patient.</p>
							</div>
						</div>

						<div class="card" style="margin-top: 1.5rem;">
							<div class="card-header"><span class="card-title">Medical Info</span></div>
							{#if patientDetails?.medical_history}
								<div class="detail-block">
									<span class="detail-label">History</span>
									<p style="margin: 6px 0 0; line-height: 1.6;">{patientDetails.medical_history}</p>
								</div>
							{/if}
							<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin-top: 1rem;">
								<div>
									<span class="detail-label">Diagnoses</span>
									<div class="tag-list" style="margin-top: 6px;">
										{#each (patientDetails?.diagnoses || []) as d}
											<span class="badge badge-info">{d}</span>
										{:else}
											<span style="color: var(--text-muted); font-size: 0.85rem;">None recorded</span>
										{/each}
									</div>
								</div>
								<div>
									<span class="detail-label">Allergies</span>
									<div class="tag-list" style="margin-top: 6px;">
										{#each (patientDetails?.allergies || []) as a}
											<span class="badge badge-danger">{a}</span>
										{:else}
											<span style="color: var(--text-muted); font-size: 0.85rem;">NKDA</span>
										{/each}
									</div>
								</div>
							</div>
						</div>
					{:else}
						<!-- Edit mode -->
						<div class="card">
							<div class="card-header">
								<span class="card-title">Edit Physical Details</span>
								<div style="display: flex; gap: 8px;">
									<button class="btn btn-sm btn-secondary" on:click={() => editingPhysical = false} disabled={savingPhysical}>Cancel</button>
									<button class="btn btn-sm btn-primary" on:click={savePhysicalDetails} disabled={savingPhysical}>
										{savingPhysical ? 'Saving…' : 'Save Changes'}
									</button>
								</div>
							</div>

							<div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 14px; margin-bottom: 20px;">
								<div class="form-group" style="margin: 0;">
									<label for="pf-gender">Gender</label>
									<select id="pf-gender" bind:value={physicalForm.gender} style="width: 100%; padding: 8px 10px; border: 1px solid var(--border); border-radius: 8px; background: var(--bg); font-size: 0.9rem;">
										<option value="">Not specified</option>
										<option value="male">Male</option>
										<option value="female">Female</option>
										<option value="other">Other</option>
										<option value="prefer not to say">Prefer not to say</option>
									</select>
								</div>
								<div class="form-group" style="margin: 0;">
									<label for="pf-height">Height (cm)</label>
									<input id="pf-height" type="number" bind:value={physicalForm.height_cm} placeholder="e.g. 165" min="50" max="250" />
								</div>
								<div class="form-group" style="margin: 0;">
									<label for="pf-weight">Weight (kg)</label>
									<input id="pf-weight" type="number" bind:value={physicalForm.weight_kg} placeholder="e.g. 70.5" min="20" max="300" step="0.1" />
								</div>
							</div>

							<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 14px; margin-bottom: 20px;">
								<div class="form-group" style="margin: 0;">
									<label for="pf-vision">Vision</label>
									<input id="pf-vision" type="text" bind:value={physicalForm.vision_score} placeholder="e.g. 20/20, wears glasses" />
								</div>
								<div class="form-group" style="margin: 0;">
									<label for="pf-companion">AI Companion Name</label>
									<input id="pf-companion" type="text" bind:value={physicalForm.ai_companion_name} placeholder="e.g. James, Rose, Alex" />
								</div>
							</div>

							<div class="form-group">
								<label for="pf-hearing">Hearing Notes</label>
								<textarea id="pf-hearing" bind:value={physicalForm.hearing_notes} placeholder="Any hearing aids, loss, preferences…" rows="2"></textarea>
							</div>

							<div class="form-group">
								<label for="pf-history">Medical History</label>
								<textarea id="pf-history" bind:value={physicalForm.medical_history} placeholder="Relevant medical background…" rows="3"></textarea>
							</div>

							<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 14px;">
								<div class="form-group" style="margin: 0;">
									<label for="pf-diagnoses">Diagnoses <span style="font-weight: 400; color: var(--text-muted);">(comma-separated)</span></label>
									<input id="pf-diagnoses" type="text" bind:value={physicalForm.diagnoses} placeholder="e.g. Diabetes, Hypertension" />
								</div>
								<div class="form-group" style="margin: 0;">
									<label for="pf-allergies">Allergies <span style="font-weight: 400; color: var(--text-muted);">(comma-separated)</span></label>
									<input id="pf-allergies" type="text" bind:value={physicalForm.allergies} placeholder="e.g. Penicillin, Peanuts" />
								</div>
							</div>
						</div>
					{/if}
				</div>
			{/if}

			<!-- ── Family & Contacts ── -->
			{#if activeTab === 'family'}
				<div class="fade-in">
					<!-- Join code banner -->
					<div class="card" style="margin-bottom: 1.5rem; background: linear-gradient(135deg, #eff6ff 0%, #dbeafe 100%); border: 1px solid #bfdbfe;">
						<div style="display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 16px;">
							<div>
								<div style="font-weight: 700; font-size: 1rem; color: #1e40af; margin-bottom: 4px;">Family Join Code</div>
								<p style="margin: 0; font-size: 0.85rem; color: #3b82f6;">Share with family members so they can link via the CareBridge app.</p>
							</div>
							<div style="display: flex; align-items: center; gap: 12px;">
								<code style="font-size: 2rem; font-weight: 800; letter-spacing: 0.15em; color: #1e40af; background: white; padding: 8px 20px; border-radius: 10px; border: 1.5px solid #bfdbfe;">
									{patientJoinCode || '——'}
								</code>
								{#if patientJoinCode}
									<button class="btn btn-sm btn-secondary" on:click={() => copyToClipboard(patientJoinCode)}>
										<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
										Copy
									</button>
								{/if}
							</div>
						</div>
					</div>

					<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1.5rem;">
						<!-- Emergency Contacts -->
						<div class="card">
							<div class="card-header">
								<span class="card-title">Emergency Contacts</span>
								{#if patientDetails?.emergency_contacts?.length}
									<span class="badge badge-info">{patientDetails.emergency_contacts.length}</span>
								{/if}
							</div>
							{#if patientDetails?.emergency_contacts?.length}
								<div style="display: flex; flex-direction: column; gap: 10px;">
									{#each patientDetails.emergency_contacts as contact}
										<div style="display: flex; align-items: center; gap: 14px; padding: 12px 14px; border-radius: 10px; background: var(--bg); border: 1px solid var(--border);">
											<div style="width: 42px; height: 42px; border-radius: 50%; background: {contact.isPrimary ? '#dbeafe' : '#f1f5f9'}; display: flex; align-items: center; justify-content: center; flex-shrink: 0; font-weight: 700; color: {contact.isPrimary ? '#1e40af' : '#64748b'}; font-size: 1rem;">
												{contact.name?.[0] || '?'}
											</div>
											<div style="flex: 1; min-width: 0;">
												<div style="display: flex; align-items: center; gap: 8px; margin-bottom: 2px;">
													<span style="font-weight: 600; font-size: 0.95rem;">{contact.name}</span>
													{#if contact.isPrimary}
														<span class="badge badge-danger" style="font-size: 0.65rem; padding: 1px 6px;">PRIMARY</span>
													{/if}
												</div>
												<div style="font-size: 0.82rem; color: var(--text-muted);">{contact.relation} · {contact.phone}</div>
											</div>
											<a href="tel:{contact.phone.replace(/\D/g,'')}" style="display: flex; align-items: center; justify-content: center; width: 34px; height: 34px; border-radius: 8px; background: #dcfce7; color: #16a34a; flex-shrink: 0; text-decoration: none;">
												<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07A19.5 19.5 0 0 1 4.69 15.1a19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 3.58 4.5h3a2 2 0 0 1 2 1.72c.13.96.36 1.9.7 2.81a2 2 0 0 1-.45 2.11L7.91 12a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.91.34 1.85.57 2.81.7A2 2 0 0 1 22 18.92z"/></svg>
											</a>
										</div>
									{/each}
								</div>
							{:else}
								<div style="text-align: center; padding: 24px; color: var(--text-muted);">
									<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" style="margin-bottom: 8px; opacity: 0.4;"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07A19.5 19.5 0 0 1 4.69 15.1a19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 3.58 4.5h3a2 2 0 0 1 2 1.72c.13.96.36 1.9.7 2.81a2 2 0 0 1-.45 2.11L7.91 12a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.91.34 1.85.57 2.81.7A2 2 0 0 1 22 18.92z"/></svg>
									<p style="margin: 0; font-size: 0.9rem;">No emergency contacts listed.</p>
								</div>
							{/if}
						</div>

						<!-- Care Team -->
						<div class="card">
							<div class="card-header">
								<span class="card-title">Care Team</span>
								{#if patientDetails?.care_team?.length}
									<span class="badge badge-info">{patientDetails.care_team.length}</span>
								{/if}
							</div>
							{#if patientDetails?.care_team?.length}
								<div style="display: flex; flex-direction: column; gap: 10px;">
									{#each patientDetails.care_team as member}
										<div style="display: flex; align-items: center; gap: 14px; padding: 12px 14px; border-radius: 10px; background: var(--bg); border: 1px solid var(--border);">
											<div style="width: 42px; height: 42px; border-radius: 50%; background: #f0fdf4; display: flex; align-items: center; justify-content: center; flex-shrink: 0;">
												<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#16a34a" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>
											</div>
											<div style="flex: 1; min-width: 0;">
												<div style="font-weight: 600; font-size: 0.95rem; margin-bottom: 2px;">{member.name}</div>
												<div style="font-size: 0.82rem; color: var(--text-muted);">{member.role}{member.organization ? ` · ${member.organization}` : ''}</div>
											</div>
										</div>
									{/each}
								</div>
							{:else}
								<div style="text-align: center; padding: 24px; color: var(--text-muted);">
									<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" style="margin-bottom: 8px; opacity: 0.4;"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
									<p style="margin: 0; font-size: 0.9rem;">No care team members listed.</p>
								</div>
							{/if}
						</div>
					</div>
				</div>
			{/if}
		</main>
	</div>
{/if}

<style>
	/* ─── Loading ────────────────────────────── */
	.loading-full {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: 100vh;
		gap: 16px;
		color: var(--text-secondary);
	}

	.loading-spinner {
		width: 40px;
		height: 40px;
		border: 3px solid var(--border);
		border-top-color: var(--primary);
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	/* ─── Shared Portal Layout ───────────────── */
	.portal-page {
		min-height: 100vh;
		display: flex;
		flex-direction: column;
		background: var(--bg);
	}

	.portal-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 0 32px;
		height: 68px;
		background: var(--card);
		border-bottom: 1px solid var(--border);
		position: sticky;
		top: 0;
		z-index: 10;
	}

	.portal-brand {
		display: flex;
		align-items: center;
		gap: 12px;
	}

	.portal-logo {
		width: 40px;
		height: 40px;
		border-radius: 10px;
		object-fit: contain;
	}

	.portal-brand-name {
		font-family: Palatino, 'Palatino Linotype', 'Book Antiqua', Georgia, serif;
		font-size: 1.3rem;
		font-weight: 700;
		color: var(--text);
		letter-spacing: -0.02em;
	}

	.family-viewing-badge {
		background: #dbeafe;
		color: #1e40af;
		font-size: 12px;
		font-weight: 600;
		padding: 3px 10px;
		border-radius: 999px;
	}

	.signout-btn {
		display: flex;
		align-items: center;
		gap: 7px;
		font-size: 13px;
	}

	.portal-body {
		flex: 1;
		padding: 40px;
		max-width: 860px;
		margin: 0 auto;
		width: 100%;
	}

	/* ─── Patient App-Only ───────────────────── */
	.app-only-card {
		background: var(--card);
		border-radius: 20px;
		padding: 56px 48px;
		text-align: center;
		box-shadow: var(--shadow);
		border: 1px solid var(--border);
	}

	.app-icon-wrap {
		width: 80px;
		height: 80px;
		background: linear-gradient(135deg, #3b82f6, #1d4ed8);
		border-radius: 20px;
		display: flex;
		align-items: center;
		justify-content: center;
		margin: 0 auto 28px;
		padding: 10px;
	}

	.app-icon { width: 100%; height: 100%; object-fit: contain; }

	.app-only-card h2 {
		margin-bottom: 16px;
	}

	.app-only-card p {
		color: var(--text-secondary);
		line-height: 1.75;
		max-width: 440px;
		margin: 0 auto 32px;
	}

	.app-badge-row { display: flex; justify-content: center; margin-bottom: 24px; }

	.app-store-badge {
		display: flex;
		align-items: center;
		gap: 8px;
		background: #0f172a;
		color: white;
		padding: 12px 24px;
		border-radius: 12px;
		font-weight: 600;
		font-size: 14px;
		cursor: default;
	}

	.portal-user-note { font-size: 13px; color: var(--text-light); }

	/* ─── Family Join Gate ───────────────────── */
	.join-code-gate {
		background: var(--card);
		border-radius: 20px;
		padding: 56px 48px;
		text-align: center;
		box-shadow: var(--shadow);
		border: 1px solid var(--border);
	}

	.join-icon {
		width: 80px;
		height: 80px;
		background: #eff6ff;
		border-radius: 20px;
		display: flex;
		align-items: center;
		justify-content: center;
		margin: 0 auto 28px;
	}

	.join-code-gate h2 { margin-bottom: 16px; }

	.join-code-gate p {
		color: var(--text-secondary);
		line-height: 1.75;
		max-width: 400px;
		margin: 0 auto 32px;
	}

	.code-input-row {
		display: flex;
		gap: 10px;
		max-width: 360px;
		margin: 0 auto;
	}

	.code-input-row input {
		flex: 1;
		padding: 11px 16px;
		border: 1.5px solid var(--border);
		border-radius: 10px;
		font-size: 1rem;
		font-family: inherit;
		outline: none;
		text-align: center;
		transition: border-color 0.2s;
	}

	.code-input-row input:focus { border-color: var(--primary); box-shadow: 0 0 0 3px rgba(59,130,246,0.1); }

	/* ─── Family Dashboard ───────────────────── */
	.family-dashboard { display: flex; flex-direction: column; gap: 20px; }

	.patient-summary-card {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 24px 28px;
	}

	.patient-summary-left { display: flex; align-items: center; gap: 18px; }

	.patient-avatar-lg {
		width: 60px;
		height: 60px;
		border-radius: 50%;
		color: white;
		font-weight: 800;
		font-size: 20px;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}

	.patient-name-lg { font-size: 1.3rem; font-weight: 700; margin-bottom: 6px; font-family: inherit; }

	.score-circle {
		width: 72px;
		height: 72px;
		border-radius: 50%;
		border: 6px solid var(--border);
		border-top-color: var(--c, #10b981);
		display: flex;
		align-items: center;
		justify-content: center;
		margin: 0 auto 6px;
	}

	.score-circle span { font-size: 1.3rem; font-weight: 800; }
	.score-circle-label { font-size: 11px; color: var(--text-secondary); font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; text-align: center; display: block; }

	.family-tabs {
		display: flex;
		gap: 4px;
		background: var(--card);
		border: 1px solid var(--border);
		border-radius: 12px;
		padding: 4px;
	}

	.family-tab {
		flex: 1;
		padding: 9px 16px;
		border: none;
		border-radius: 9px;
		font-size: 14px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.15s;
		background: transparent;
		color: var(--text-secondary);
	}

	.family-tab.active { background: var(--bg); color: var(--text); box-shadow: var(--shadow-sm); }

	.meds-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 20px; }

	.med-name { font-size: 1rem; font-weight: 700; margin-bottom: 4px; }
	.med-detail { font-size: 13px; color: var(--text-secondary); margin-bottom: 8px; }
	.med-note { font-size: 13px; color: var(--text-light); line-height: 1.5; }

	.family-table-head { display: grid; grid-template-columns: 1fr 80px 80px 80px 1fr; gap: 8px; align-items: center; padding: 10px 12px; border-radius: 8px; background: var(--bg); font-size: 12px; font-weight: 700; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 0.04em; }
	.family-table-row { display: grid; grid-template-columns: 1fr 80px 80px 80px 1fr; gap: 8px; align-items: center; padding: 10px 12px; border-bottom: 1px solid var(--border); font-size: 13px; }
	.family-table-row:last-child { border: none; }

	/* ─── Full Dashboard Shell ───────────────── */
	.app-shell {
		display: flex;
		min-height: 100vh;
		background: var(--bg);
	}

	/* ─── Sidebar ────────────────────────────── */
	.sidebar {
		width: 260px;
		min-height: 100vh;
		background: var(--card);
		border-right: 1px solid var(--border);
		display: flex;
		flex-direction: column;
		transition: width 0.25s ease;
		position: fixed;
		top: 0;
		left: 0;
		z-index: 100;
		overflow: hidden;
	}

	.sidebar.collapsed { width: 64px; }

	.sidebar-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 0 20px;
		border-bottom: 1px solid var(--border);
		height: 68px;
		min-height: 68px;
		flex-shrink: 0;
	}

	.sidebar.collapsed .sidebar-header {
		justify-content: center;
		padding: 0;
	}

	.brand {
		display: flex;
		align-items: center;
		gap: 11px;
		overflow: hidden;
		flex: 1;
	}

	.brand-logo {
		width: 40px;
		height: 40px;
		border-radius: 10px;
		object-fit: contain;
		flex-shrink: 0;
	}

	.brand-name {
		font-family: Palatino, 'Palatino Linotype', 'Book Antiqua', Georgia, serif;
		font-size: 1.3rem;
		font-weight: 700;
		color: var(--text);
		white-space: nowrap;
		letter-spacing: -0.02em;
	}

	.collapse-btn {
		background: none;
		border: 1px solid var(--border);
		border-radius: 6px;
		width: 28px;
		height: 28px;
		cursor: pointer;
		color: var(--text-secondary);
		flex-shrink: 0;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: background 0.15s;
	}

	.collapse-btn:hover { background: var(--bg); }

	.sidebar-nav {
		padding: 16px 10px;
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.nav-item {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 10px 12px;
		border: none;
		border-radius: 10px;
		background: none;
		cursor: pointer;
		font-size: 14px;
		font-weight: 500;
		color: var(--text-secondary);
		transition: all 0.15s;
		text-align: left;
		white-space: nowrap;
		width: 100%;
	}

	.sidebar.collapsed .nav-item {
		justify-content: center;
		padding: 10px;
	}

	.nav-item:hover { background: var(--bg); color: var(--text); }
	.nav-item.active { background: #dbeafe; color: var(--primary-dark); font-weight: 600; }

	.nav-icon { flex-shrink: 0; width: 18px; height: 18px; display: flex; align-items: center; justify-content: center; }
	.nav-label { overflow: hidden; }

	.sidebar-section {
		flex: 1;
		overflow-y: auto;
		padding: 0 10px;
		border-top: 1px solid var(--border);
	}

	.section-label {
		font-size: 11px;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.08em;
		color: var(--text-light);
		padding: 16px 8px 8px;
	}

	.patient-list { display: flex; flex-direction: column; gap: 2px; }

	.patient-item {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 8px 10px;
		border: none;
		border-radius: 8px;
		background: none;
		cursor: pointer;
		width: 100%;
		text-align: left;
		transition: background 0.15s;
	}

	.patient-item:hover { background: var(--bg); }
	.patient-item.selected { background: #eff6ff; }

	.patient-avatar-sm {
		width: 30px; height: 30px; border-radius: 50%; color: white;
		font-weight: 700; font-size: 13px; display: flex; align-items: center;
		justify-content: center; flex-shrink: 0;
	}

	.patient-meta { display: flex; flex-direction: column; overflow: hidden; flex: 1; }
	.patient-name-sm { font-size: 13px; font-weight: 600; color: var(--text); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
	.patient-score-sm { font-size: 12px; font-weight: 700; }
	.no-patients { font-size: 13px; color: var(--text-light); padding: 12px 8px; }

	.sidebar-footer {
		padding: 16px 10px;
		border-top: 1px solid var(--border);
	}

	.user-info {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 8px 10px;
		border-radius: 10px;
		background: var(--bg);
	}

	.sidebar.collapsed .user-info {
		justify-content: center;
		padding: 8px 0;
	}

	.user-avatar {
		width: 32px; height: 32px; border-radius: 50%;
		background: linear-gradient(135deg, var(--primary), var(--primary-dark));
		color: white; font-weight: 700; font-size: 13px;
		display: flex; align-items: center; justify-content: center; flex-shrink: 0;
	}

	.user-details { display: flex; flex-direction: column; overflow: hidden; flex: 1; }
	.user-name { font-size: 13px; font-weight: 700; color: var(--text); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
	.user-role { font-size: 11px; color: var(--text-light); text-transform: capitalize; }

	.logout-btn {
		background: none;
		border: 1px solid var(--border);
		border-radius: 7px;
		cursor: pointer;
		padding: 5px 9px;
		font-size: 12px;
		color: var(--text-secondary);
		display: flex;
		align-items: center;
		gap: 5px;
		white-space: nowrap;
		flex-shrink: 0;
		transition: all 0.15s;
	}

	.logout-btn:hover { background: #fee2e2; color: var(--danger); border-color: #fecaca; }

	/* ─── Main ───────────────────────────────── */
	.main {
		margin-left: 260px;
		flex: 1;
		padding: 32px;
		transition: margin-left 0.25s ease;
		max-width: calc(100vw - 260px);
	}

	.main.collapsed {
		margin-left: 64px;
		max-width: calc(100vw - 64px);
	}

	/* ─── Page Header ────────────────────────── */
	.page-header {
		display: flex;
		align-items: flex-start;
		justify-content: space-between;
		margin-bottom: 28px;
	}

	.page-header h1 { font-size: 1.6rem; font-weight: 700; letter-spacing: -0.02em; }
	.page-subtitle { color: var(--text-secondary); font-size: 14px; margin-top: 4px; }

	.header-patient-badge {
		display: flex; align-items: center; gap: 12px;
		background: var(--card); border: 1px solid var(--border);
		border-radius: 12px; padding: 12px 16px;
	}

	.avatar-md {
		width: 44px; height: 44px; border-radius: 50%; color: white;
		font-weight: 800; font-size: 16px; display: flex; align-items: center; justify-content: center;
	}

	.score-value { font-size: 1.5rem; font-weight: 800; line-height: 1; }
	.score-sublabel { font-size: 11px; color: var(--text-secondary); font-weight: 600; text-transform: uppercase; letter-spacing: 0.04em; }

	/* ─── Fade-in sections: uniform vertical stacking ─── */
	.fade-in {
		display: flex;
		flex-direction: column;
		gap: 20px;
	}

	/* ─── Stats Row ──────────────────────────── */
	.stats-row { display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; }
	.stat-card { text-align: center; }
	.stat-value { font-size: 2rem; font-weight: 800; line-height: 1; margin-bottom: 4px; }
	.stat-label { font-size: 12px; color: var(--text-secondary); font-weight: 600; text-transform: uppercase; letter-spacing: 0.04em; }

	/* ─── AI Overview ───────────────────────── */
	.ai-overview-card { border-left: 3px solid var(--secondary); }
	.ai-overview-text {
		font-size: 14px;
		line-height: 1.8;
		color: var(--text-secondary);
	}
	.ai-overview-empty {
		font-size: 13px;
		color: var(--text-light);
		line-height: 1.7;
		font-style: italic;
	}

	/* ─── Score ──────────────────────────────── */
	.score-display { display: flex; align-items: center; gap: 32px; }
	.score-ring {
		width: 100px; height: 100px; border-radius: 50%;
		border: 8px solid var(--border); border-top-color: var(--color);
		display: flex; align-items: center; justify-content: center; flex-shrink: 0;
	}
	.score-number { font-size: 1.8rem; font-weight: 800; }
	.score-bar-wrapper { flex: 1; }
	.score-track { height: 14px; background: var(--border); border-radius: 7px; overflow: hidden; margin-bottom: 8px; }
	.score-fill { height: 100%; border-radius: 7px; transition: width 0.6s ease; }
	.score-markers { display: flex; justify-content: space-between; font-size: 11px; color: var(--text-light); }

	/* ─── Table ──────────────────────────────── */
	.checkin-table { display: flex; flex-direction: column; gap: 2px; }

	.table-head, .table-row {
		display: grid;
		grid-template-columns: 130px 70px 70px 70px 1fr;
		gap: 8px; align-items: center;
		padding: 10px 12px; border-radius: 8px; font-size: 13px;
	}

	.table-head { background: var(--bg); font-weight: 700; color: var(--text-secondary); font-size: 12px; text-transform: uppercase; letter-spacing: 0.04em; }
	.table-row { border-bottom: 1px solid var(--border); }
	.table-row:last-child { border: none; }

	.roster-head, .roster-row { grid-template-columns: 160px 1fr 80px 1fr 90px; }

	.metric-chip { background: var(--bg); border-radius: 6px; padding: 2px 8px; font-weight: 700; text-align: center; font-size: 13px; }
	.note-preview { color: var(--text-secondary); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
	.empty-row { padding: 20px; text-align: center; color: var(--text-secondary); }

	/* ─── Sliders ────────────────────────────── */
	.sliders-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 20px; }
	.slider-card { background: var(--bg); border-radius: 12px; padding: 16px; border: 1px solid var(--border); }
	.slider-header { display: flex; align-items: center; gap: 8px; margin-bottom: 12px; }
	.slider-icon { width: 20px; height: 20px; display: inline-flex; flex-shrink: 0; }
	:global(.slider-icon svg) { width: 100%; height: 100%; }
	.slider-name { font-weight: 600; font-size: 14px; flex: 1; }
	.slider-val { font-size: 1.4rem; font-weight: 800; color: var(--primary); min-width: 28px; text-align: right; }
	.range-input { width: 100%; height: 6px; border-radius: 3px; background: var(--border); outline: none; -webkit-appearance: none; appearance: none; cursor: pointer; }
	.range-input::-webkit-slider-thumb { -webkit-appearance: none; width: 20px; height: 20px; border-radius: 50%; background: var(--primary); cursor: pointer; box-shadow: 0 2px 6px rgba(59,130,246,0.4); }
	.slider-labels { display: flex; justify-content: space-between; margin-top: 6px; font-size: 11px; color: var(--text-light); }

	/* ─── Notes ──────────────────────────────── */
	.notes-list { display: flex; flex-direction: column; gap: 20px; }
	.note-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 10px; }
	.note-date { font-size: 12px; color: var(--text-light); }
	.note-content { color: var(--text-secondary); line-height: 1.7; font-size: 14px; }

	/* ─── Insights ───────────────────────────── */
	.insights-list { display: flex; flex-direction: column; gap: 20px; }
	.insight-header { display: flex; align-items: flex-start; gap: 14px; margin-bottom: 10px; }
	.insight-title { font-size: 1rem; font-weight: 700; margin-bottom: 4px; font-family: inherit; }
	.insight-desc { color: var(--text-secondary); font-size: 14px; line-height: 1.7; }
	.insight-date { font-size: 12px; color: var(--text-light); margin-top: 10px; }

	/* ─── States ─────────────────────────────── */
	.empty-state { text-align: center; padding: 60px 32px; }
	.empty-icon { margin-bottom: 16px; display: flex; justify-content: center; }
	.empty-state h3 { margin-bottom: 8px; }
	.empty-state p { color: var(--text-secondary); }
	.empty-card { display: flex; align-items: center; justify-content: space-between; color: var(--text-secondary); font-size: 14px; }

	.mini-spinner {
		width: 14px; height: 14px; border: 2px solid rgba(255,255,255,0.3);
		border-top-color: white; border-radius: 50%;
		animation: spin 0.7s linear infinite; display: inline-block;
	}

	@keyframes spin { to { transform: rotate(360deg); } }

	@media (max-width: 1100px) {
		.stats-row { grid-template-columns: repeat(2, 1fr); }
		.sliders-grid { grid-template-columns: 1fr; }
	}

	/* ─── Alerts Panel ──────────────────────── */
	/* ─── Organization card ─────────────────────── */
	.org-card {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 16px;
		background: var(--card, #fff);
		border: 1px solid var(--border, #e5e7eb);
		border-radius: 14px;
		padding: 16px 20px;
		margin-bottom: 20px;
		flex-wrap: wrap;
	}
	.org-card-main { display: flex; align-items: center; gap: 14px; }
	.org-badge {
		width: 44px; height: 44px; border-radius: 12px; flex-shrink: 0;
		background: var(--primary, #3b82f6); color: #fff;
		display: flex; align-items: center; justify-content: center;
		font-weight: 800; font-size: 1.2rem;
	}
	.org-name { font-weight: 700; font-size: 1.05rem; }
	.org-meta { font-size: 0.82rem; color: var(--text-muted, #6b7280); margin-top: 2px; }
	.org-code-box { display: flex; align-items: center; gap: 10px; }
	.org-code-label { font-size: 0.72rem; text-transform: uppercase; letter-spacing: 0.04em; color: var(--text-muted, #6b7280); }
	.org-code {
		font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
		font-weight: 800; font-size: 1.05rem; letter-spacing: 0.08em;
		background: var(--bg, #f3f4f6); padding: 6px 12px; border-radius: 8px;
	}
	.org-setup { align-items: stretch; }
	.org-setup-col { flex: 1; min-width: 220px; }
	.org-setup-divider { width: 1px; align-self: stretch; background: var(--border, #e5e7eb); }
	.org-setup-title { font-weight: 700; margin-bottom: 4px; }
	.org-setup-sub { font-size: 0.82rem; color: var(--text-muted, #6b7280); margin: 0 0 10px; }
	.org-setup-row { display: flex; gap: 8px; }
	.org-setup-row input {
		flex: 1; padding: 8px 12px; border: 1px solid var(--border, #e5e7eb);
		border-radius: 8px; font-size: 0.9rem;
	}

	.alerts-panel {
		background: #fff7ed;
		border: 1.5px solid #fed7aa;
		border-radius: 14px;
		padding: 16px 20px;
		display: flex;
		flex-direction: column;
		gap: 10px;
	}

	.alerts-panel-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 4px;
	}

	.alerts-panel-title {
		display: flex;
		align-items: center;
		gap: 8px;
		font-size: 14px;
		font-weight: 700;
		color: #92400e;
	}

	.alerts-count {
		font-size: 12px;
		font-weight: 700;
		color: #d97706;
		background: #fef3c7;
		padding: 2px 10px;
		border-radius: 999px;
	}

	.alert-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 12px;
		padding: 10px 12px;
		background: white;
		border-radius: 10px;
		border: 1px solid #fed7aa;
	}

	.alert-row.urgent { border-color: #fca5a5; background: #fff5f5; }

	.alert-info {
		display: flex;
		align-items: center;
		gap: 10px;
		flex-wrap: wrap;
		flex: 1;
		min-width: 0;
	}

	.alert-patient { font-size: 13px; font-weight: 700; color: var(--text); }
	.alert-msg { font-size: 13px; color: var(--text-secondary); flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
	.alert-time { font-size: 11px; color: var(--text-light); white-space: nowrap; }

	/* ─── Patient Accordion ─────────────────── */
	.patient-accordion { display: flex; flex-direction: column; }

	.patient-chevron {
		flex-shrink: 0;
		color: var(--text-light);
		transition: transform 0.2s ease;
	}

	.patient-chevron.open { transform: rotate(180deg); }

	.patient-subnav {
		display: flex;
		flex-direction: column;
		gap: 1px;
		padding: 4px 0 4px 16px;
		margin: 0 0 4px;
		border-left: 2px solid var(--border);
		margin-left: 20px;
	}

	.subnav-item {
		display: block;
		width: 100%;
		text-align: left;
		padding: 7px 10px;
		border: none;
		border-radius: 7px;
		background: none;
		font-size: 13px;
		font-weight: 500;
		color: var(--text-secondary);
		cursor: pointer;
		transition: all 0.15s;
		white-space: nowrap;
	}

	.subnav-item:hover { background: var(--bg); color: var(--text); }
	.subnav-item.active { background: #dbeafe; color: var(--primary-dark); font-weight: 600; }

	/* ─── AI Overview full page ─────────────── */
	.ai-overview-meta { font-size: 12px; color: var(--text-light); margin-bottom: 16px; font-weight: 500; }

	@media (max-width: 768px) {
		.sidebar { display: none; }
		.main { margin-left: 0; max-width: 100vw; padding: 20px; }
		.main.collapsed { margin-left: 0; max-width: 100vw; }
		.page-header { flex-direction: column; gap: 12px; }
		.portal-body { padding: 20px; }
	}
</style>
