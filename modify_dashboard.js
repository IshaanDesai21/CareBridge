const fs = require('fs');
let content = fs.readFileSync('dashboard/src/routes/dashboard/+page.svelte', 'utf8');

// 1. Import CustomSelect
content = content.replace(
    `	import { auth, addNotification } from '$lib/stores';`,
    `	import { auth, addNotification } from '$lib/stores';\n\timport CustomSelect from '$lib/components/CustomSelect.svelte';`
);

// 2. Default tab to 'all_patients' instead of 'overview'
content = content.replace(
    `let activeTab = 'overview'; // 'overview' | 'checkin' | 'notes' | 'insights'`,
    `let activeTab = 'all_patients'; // 'all_patients' | 'overview' | 'checkin' | 'notes' | 'insights'`
);

// 3. Remove auto-select logic that hides 'all_patients'
content = content.replace(
    `			if (patients.length > 0 && !selectedPatient) {\n				await selectPatient(patients[0]);\n			}`,
    `			// Do not auto-select patient to allow 'all_patients' view to show\n			// if (patients.length > 0 && !selectedPatient) { await selectPatient(patients[0]); }`
);

// 4. Update selectPatient to also switch tab to 'overview'
content = content.replace(
    `	async function selectPatient(patient) {\n		selectedPatient = patient;`,
    `	async function selectPatient(patient) {\n		selectedPatient = patient;\n		activeTab = 'overview';`
);

// 5. Update Nav Items
content = content.replace(
    `		<nav class="sidebar-nav">\n			{#each [\n				{ id: 'overview', icon: '⊞', label: 'Overview' },\n				{ id: 'checkin', icon: '✎', label: 'Wellness Check-in' },\n				{ id: 'notes', icon: '◎', label: 'Care Notes' },\n				{ id: 'insights', icon: '◈', label: 'AI Insights' }\n			] as item}`,
    `		<nav class="sidebar-nav">\n			{#each [\n				{ id: 'all_patients', icon: '👥', label: 'All Patients' },\n				{ id: 'overview', icon: '⊞', label: 'Patient Overview' },\n				{ id: 'checkin', icon: '✎', label: 'Wellness Check-in' },\n				{ id: 'notes', icon: '◎', label: 'Care Notes' },\n				{ id: 'insights', icon: '◈', label: 'AI Insights' }\n			] as item}`
);

// 6. Update Page Header Title logic
content = content.replace(
    `					<h1>\n						{activeTab === 'overview' ? 'Patient Overview' :\n						 activeTab === 'checkin' ? 'Wellness Check-In' :\n						 activeTab === 'notes' ? 'Care Notes' : 'AI Insights'}\n					</h1>`,
    `					<h1>\n						{activeTab === 'all_patients' ? 'All Patients Dashboard' :\n						 activeTab === 'overview' ? 'Patient Overview' :\n						 activeTab === 'checkin' ? 'Wellness Check-In' :\n						 activeTab === 'notes' ? 'Care Notes' : 'AI Insights'}\n					</h1>`
);

// 7. Add All Patients Tab Content before 'overview' content
const overviewStart = `			<!-- ── Overview ── -->\n			{#if activeTab === 'overview'}`;
const allPatientsContent = `			<!-- ── All Patients ── -->\n			{#if activeTab === 'all_patients'}\n				<div class="fade-in">\n					<div class="card">\n						<div class="card-header">\n							<span class="card-title">Patient Roster</span>\n						</div>\n						<div class="checkin-table">\n							<div class="table-head">\n								<span>Patient</span><span>Status</span><span>Wellness Score</span><span>Family Contact</span><span>Action</span>\n							</div>\n							{#each patients as p}\n								<div class="table-row">\n									<span><strong>{p.first_name} {p.last_name || ''}</strong></span>\n									<span class="badge badge-{p.wellness_score >= 80 ? 'success' : p.wellness_score >= 60 ? 'warning' : 'danger'}">{getScoreLabel(p.wellness_score)}</span>\n									<span class="metric-chip" style="color: {getScoreColor(p.wellness_score)}">{p.wellness_score || '—'}</span>\n									<span>\n										{#if (p.wellness_score || 100) < 60}\n											<span class="badge badge-danger">Needs Contact</span>\n										{:else}\n											<span class="text-muted">Up to date</span>\n										{/if}\n									</span>\n									<span>\n										<button class="btn btn-sm btn-secondary" on:click={() => selectPatient(p)}>View Details</button>\n									</span>\n								</div>\n							{/each}\n							{#if patients.length === 0}\n								<div style="padding: 20px; text-align: center; color: var(--text-secondary);">No patients found. Register a patient to get started.</div>\n							{/if}\n						</div>\n					</div>\n				</div>\n\n			<!-- ── Overview ── -->\n			{:else if activeTab === 'overview'}`;

content = content.replace(overviewStart, allPatientsContent);

// 8. Replace native select with CustomSelect
content = content.replace(
    `							<select id="note-type" bind:value={newNote.note_type}>\n								{#each NOTE_TYPES as type}\n									<option value={type}>{type.charAt(0).toUpperCase() + type.slice(1)}</option>\n								{/each}\n							</select>`,
    `							<CustomSelect\n								id="note-type"\n								bind:value={newNote.note_type}\n								options={NOTE_TYPES.map(t => ({ value: t, label: t.charAt(0).toUpperCase() + t.slice(1) }))}\n							/>`
);

fs.writeFileSync('dashboard/src/routes/dashboard/+page.svelte', content);
console.log("Updated dashboard page");
