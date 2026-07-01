<script>
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { auth, addNotification } from '$lib/stores';
	import CustomSelect from '$lib/components/CustomSelect.svelte';
	import {
		getPatients,
		submitWellnessCheckin,
		getWellnessHistory,
		getCareNotes,
		createCareNote,
		getAiInsights
	} from '$lib/api';

	let user = null;
	let patients = [];
	let selectedPatient = null;
	let wellnessHistory = [];
	let careNotes = [];
	let aiInsights = [];
	let loading = true;
	let activeTab = 'all_patients'; // 'all_patients' | 'overview' | 'checkin' | 'notes' | 'insights'
	let sidebarCollapsed = false;

	// Wellness check-in form
	let checkin = { energy: 5, mood: 5, pain: 5, fatigue: 5, appetite: 5, hydration: 5, notes: '' };
	let submittingCheckin = false;

	// Care note form
	let newNote = { content: '', note_type: 'observation' };
	let submittingNote = false;

	onMount(async () => {
		const unsub = auth.subscribe(async state => {
			if (!state.isAuthenticated) { goto('/login'); return; }
			user = state.user;
			await loadData();
			loading = false;
		});
		return unsub;
	});

	async function loadData() {
		try {
			const result = await getPatients();
			patients = (result.patients || []).sort((a, b) => (a.wellness_score || 0) - (b.wellness_score || 0));
			// Do not auto-select patient to allow 'all_patients' view to show
			// if (patients.length > 0 && !selectedPatient) { await selectPatient(patients[0]); }
		} catch (e) {
			addNotification('Failed to load patients. Is the backend running?', 'error');
		}
	}

	async function selectPatient(patient) {
		selectedPatient = patient;
		activeTab = 'overview';
		try {
			const [hist, notes, insights] = await Promise.allSettled([
				getWellnessHistory(patient.id),
				getCareNotes(patient.id),
				getAiInsights(patient.id)
			]);
			wellnessHistory = hist.value?.checkins || hist.value?.history || [];
			careNotes = notes.value?.notes || notes.value || [];
			aiInsights = insights.value?.insights || insights.value || [];
		} catch (e) {
			console.error(e);
		}
	}

	async function handleCheckin() {
		if (!selectedPatient) return;
		submittingCheckin = true;
		try {
			const result = await submitWellnessCheckin({ patientId: selectedPatient.id, ...checkin });
			selectedPatient = { ...selectedPatient, wellness_score: result.wellnessScore || selectedPatient.wellness_score };
			patients = patients.map(p => p.id === selectedPatient.id ? selectedPatient : p)
				.sort((a,b) => (a.wellness_score||0) - (b.wellness_score||0));
			addNotification('Check-in submitted successfully!', 'success');
			checkin = { energy: 5, mood: 5, pain: 5, fatigue: 5, appetite: 5, hydration: 5, notes: '' };
			activeTab = 'overview';
		} catch (e) {
			addNotification(e.message, 'error');
		} finally {
			submittingCheckin = false;
		}
	}

	async function handleAddNote() {
		if (!selectedPatient || !newNote.content.trim()) return;
		submittingNote = true;
		try {
			await createCareNote({ patientId: selectedPatient.id, ...newNote, caregiverId: user?.id });
			addNotification('Care note added.', 'success');
			newNote = { content: '', note_type: 'observation' };
			const notes = await getCareNotes(selectedPatient.id);
			careNotes = notes.notes || notes || [];
		} catch (e) {
			addNotification(e.message, 'error');
		} finally {
			submittingNote = false;
		}
	}

	function handleLogout() {
		auth.logout();
		goto('/login');
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

	const NOTE_TYPES = ['observation', 'behavior', 'equipment', 'nutrition', 'communication', 'question'];

	$: initials = selectedPatient
		? `${selectedPatient.first_name?.[0] || ''}${selectedPatient.last_name?.[0] || ''}`.toUpperCase() || '?'
		: '';
</script>

<svelte:head>
	<title>Dashboard — CareBridge</title>
	<meta name="description" content="CareBridge caregiver dashboard — monitor patient wellness and coordinate care." />
</svelte:head>

<div class="app-shell">
	<!-- Sidebar -->
	<aside class="sidebar {sidebarCollapsed ? 'collapsed' : ''}">
		<div class="sidebar-header">
			<div class="brand">
				<div class="brand-icon">
					<svg width="28" height="28" viewBox="0 0 28 28" fill="none">
						<rect width="28" height="28" rx="8" fill="url(#g)"/>
						<path d="M14 6 L14 22 M6 14 L22 14" stroke="white" stroke-width="2.5" stroke-linecap="round"/>
						<defs>
							<linearGradient id="g" x1="0" y1="0" x2="28" y2="28">
								<stop stop-color="#3b82f6"/><stop offset="1" stop-color="#1d4ed8"/>
							</linearGradient>
						</defs>
					</svg>
				</div>
				{#if !sidebarCollapsed}<span class="brand-name">CareBridge</span>{/if}
			</div>
			<button class="collapse-btn" on:click={() => sidebarCollapsed = !sidebarCollapsed} aria-label="Toggle sidebar">
				{sidebarCollapsed ? '→' : '←'}
			</button>
		</div>

		<!-- Nav -->
		<nav class="sidebar-nav">
			{#each [
				{ id: 'all_patients', icon: '👥', label: 'All Patients' },
				{ id: 'overview', icon: '⊞', label: 'Patient Overview' },
				{ id: 'checkin', icon: '✎', label: 'Wellness Check-in' },
				{ id: 'notes', icon: '◎', label: 'Care Notes' },
				{ id: 'insights', icon: '◈', label: 'AI Insights' }
			] as item}
				<button
					class="nav-item {activeTab === item.id ? 'active' : ''}"
					on:click={() => activeTab = item.id}
					aria-current={activeTab === item.id ? 'page' : undefined}
					id="nav-{item.id}"
				>
					<span class="nav-icon">{item.icon}</span>
					{#if !sidebarCollapsed}<span class="nav-label">{item.label}</span>{/if}
				</button>
			{/each}
		</nav>

		<!-- Patient list -->
		{#if !sidebarCollapsed}
			<div class="sidebar-section">
				<div class="section-label">Patients</div>
				<div class="patient-list">
					{#each patients as patient (patient.id)}
						<button
							class="patient-item {selectedPatient?.id === patient.id ? 'selected' : ''}"
							on:click={() => selectPatient(patient)}
							id="patient-{patient.id}"
						>
							<div class="patient-avatar-sm" style="background: {getScoreColor(patient.wellness_score)}">
								{patient.first_name?.[0] || patient.email?.[0] || '?'}
							</div>
							<div class="patient-meta">
								<span class="patient-name-sm">{patient.first_name} {patient.last_name || ''}</span>
								<span class="patient-score-sm" style="color: {getScoreColor(patient.wellness_score)}">
									{patient.wellness_score || '—'}
								</span>
							</div>
						</button>
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
				<div class="user-avatar">
					{user?.firstName?.[0] || user?.email?.[0] || 'U'}
				</div>
				{#if !sidebarCollapsed}
					<div class="user-details">
						<span class="user-name">{user?.firstName || user?.email}</span>
						<span class="user-role">{user?.role || 'Caregiver'}</span>
					</div>
					<button class="logout-btn" on:click={handleLogout} title="Logout" id="logout-btn">⏻</button>
				{/if}
			</div>
		</div>
	</aside>

	<!-- Main -->
	<main class="main">
		{#if loading}
			<div class="loading-state">
				<div class="loading-spinner"></div>
				<p>Loading your dashboard…</p>
			</div>
		{:else}
			<!-- Page header -->
			<header class="page-header">
				<div>
					<h1>
						{activeTab === 'all_patients' ? 'All Patients Dashboard' :
						 activeTab === 'overview' ? 'Patient Overview' :
						 activeTab === 'checkin' ? 'Wellness Check-In' :
						 activeTab === 'notes' ? 'Care Notes' : 'AI Insights'}
					</h1>
					{#if selectedPatient}
						<p class="page-subtitle">
							{selectedPatient.first_name} {selectedPatient.last_name || ''} · Last updated {formatDate(selectedPatient.updated_at)}
						</p>
					{/if}
				</div>
				{#if selectedPatient}
					<div class="header-patient-badge">
						<div class="avatar-md" style="background: {getScoreColor(selectedPatient.wellness_score)}">
							{initials}
						</div>
						<div>
							<div class="score-value" style="color: {getScoreColor(selectedPatient.wellness_score)}">
								{selectedPatient.wellness_score || '—'}
							</div>
							<div class="score-sublabel">{getScoreLabel(selectedPatient.wellness_score)}</div>
						</div>
					</div>
				{/if}
			</header>

			<!-- ── All Patients ── -->
			{#if activeTab === 'all_patients'}
				<div class="fade-in">
					<div class="card">
						<div class="card-header">
							<span class="card-title">Patient Roster</span>
						</div>
						<div class="checkin-table">
							<div class="table-head">
								<span>Patient</span><span>Status</span><span>Wellness Score</span><span>Family Contact</span><span>Action</span>
							</div>
							{#each patients as p}
								<div class="table-row">
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
										<button class="btn btn-sm btn-secondary" on:click={() => selectPatient(p)}>View Details</button>
									</span>
								</div>
							{/each}
							{#if patients.length === 0}
								<div style="padding: 20px; text-align: center; color: var(--text-secondary);">No patients found. Register a patient to get started.</div>
							{/if}
						</div>
					</div>
				</div>

			<!-- ── Overview ── -->
			{:else if activeTab === 'overview'}
				<div class="fade-in">
					{#if !selectedPatient}
						<div class="empty-state card">
							<div class="empty-icon">👥</div>
							<h3>No patients found</h3>
							<p>Register a patient account to get started.</p>
						</div>
					{:else}
						<!-- Stats row -->
						<div class="stats-row">
							{#each [
								{ label: 'Wellness Score', value: selectedPatient.wellness_score || '—', color: getScoreColor(selectedPatient.wellness_score), icon: '◉' },
								{ label: 'Check-ins', value: wellnessHistory.length, color: '#3b82f6', icon: '✎' },
								{ label: 'Care Notes', value: careNotes.length, color: '#8b5cf6', icon: '◎' },
								{ label: 'AI Insights', value: aiInsights.length, color: '#14b8a6', icon: '◈' }
							] as stat}
								<div class="stat-card card">
									<div class="stat-icon" style="color: {stat.color}">{stat.icon}</div>
									<div class="stat-value" style="color: {stat.color}">{stat.value}</div>
									<div class="stat-label">{stat.label}</div>
								</div>
							{/each}
						</div>

						<!-- Wellness score visualization -->
						<div class="card">
							<div class="card-header">
								<span class="card-title">Wellness Score</span>
								<span class="badge badge-{selectedPatient.wellness_score >= 80 ? 'success' : selectedPatient.wellness_score >= 60 ? 'warning' : 'danger'}">
									{getScoreLabel(selectedPatient.wellness_score)}
								</span>
							</div>
							<div class="score-display">
								<div class="score-ring" style="--score: {selectedPatient.wellness_score || 0}; --color: {getScoreColor(selectedPatient.wellness_score)}">
									<span class="score-number" style="color: {getScoreColor(selectedPatient.wellness_score)}">
										{selectedPatient.wellness_score || 0}
									</span>
								</div>
								<div class="score-bar-wrapper">
									<div class="score-track">
										<div class="score-fill" style="width: {selectedPatient.wellness_score || 0}%; background: {getScoreColor(selectedPatient.wellness_score)}"></div>
									</div>
									<div class="score-markers">
										<span>0</span><span>Critical</span><span>Moderate</span><span>Excellent</span><span>100</span>
									</div>
								</div>
							</div>
						</div>

						<!-- Recent check-ins -->
						{#if wellnessHistory.length > 0}
							<div class="card">
								<div class="card-header">
									<span class="card-title">Recent Check-ins</span>
									<button class="btn btn-sm btn-secondary" on:click={() => activeTab = 'checkin'}>+ New Check-in</button>
								</div>
								<div class="checkin-table">
									<div class="table-head">
										<span>Date</span><span>Energy</span><span>Mood</span><span>Pain</span><span>Notes</span>
									</div>
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

			<!-- ── Wellness Check-in ── -->
			{:else if activeTab === 'checkin'}
				<div class="card fade-in">
					<div class="card-header">
						<span class="card-title">Daily Wellness Check-In</span>
						<span class="text-muted">Track how {selectedPatient?.first_name || 'the patient'} is feeling today</span>
					</div>

					<div class="sliders-grid">
						{#each [
							{ key: 'energy', label: 'Energy', emoji: '⚡', lowLabel: 'Exhausted', highLabel: 'Energized' },
							{ key: 'mood', label: 'Mood', emoji: '😊', lowLabel: 'Very Low', highLabel: 'Great' },
							{ key: 'pain', label: 'Pain Level', emoji: '🩹', lowLabel: 'No Pain', highLabel: 'Severe' },
							{ key: 'fatigue', label: 'Fatigue', emoji: '😴', lowLabel: 'Alert', highLabel: 'Exhausted' },
							{ key: 'appetite', label: 'Appetite', emoji: '🍽', lowLabel: 'None', highLabel: 'Normal' },
							{ key: 'hydration', label: 'Hydration', emoji: '💧', lowLabel: 'Dehydrated', highLabel: 'Well-hydrated' }
						] as slider}
							<div class="slider-card">
								<div class="slider-header">
									<span class="slider-emoji">{slider.emoji}</span>
									<span class="slider-name">{slider.label}</span>
									<span class="slider-val">{checkin[slider.key]}</span>
								</div>
								<input
									type="range"
									min="1"
									max="10"
									id="slider-{slider.key}"
									bind:value={checkin[slider.key]}
									class="range-input"
								/>
								<div class="slider-labels">
									<span>{slider.lowLabel}</span><span>{slider.highLabel}</span>
								</div>
							</div>
						{/each}
					</div>

					<div class="form-group" style="margin-top: 24px;">
						<label for="checkin-notes">Additional Notes</label>
						<textarea
							id="checkin-notes"
							bind:value={checkin.notes}
							placeholder="Any observations, concerns, or context…"
							rows="3"
						></textarea>
					</div>

					<button
						class="btn btn-primary"
						on:click={handleCheckin}
						disabled={submittingCheckin || !selectedPatient}
						id="submit-checkin-btn"
					>
						{#if submittingCheckin}
							<span class="mini-spinner"></span> Submitting…
						{:else}
							✓ Submit Check-In
						{/if}
					</button>
				</div>

			<!-- ── Care Notes ── -->
			{:else if activeTab === 'notes'}
				<div class="fade-in">
					<div class="card">
						<div class="card-header">
							<span class="card-title">Add Care Note</span>
						</div>
						<div class="form-group">
							<label for="note-type">Note Type</label>
							<CustomSelect
								id="note-type"
								bind:value={newNote.note_type}
								options={NOTE_TYPES.map(t => ({ value: t, label: t.charAt(0).toUpperCase() + t.slice(1) }))}
							/>
						</div>
						<div class="form-group">
							<label for="note-content">Note</label>
							<textarea
								id="note-content"
								bind:value={newNote.content}
								placeholder="Describe your observation, concern, or update…"
								rows="4"
							></textarea>
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
						<div class="card empty-card">No care notes yet. Add your first note above.</div>
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
										<div class="insight-icon">◈</div>
										<div>
											<h3 class="insight-title">{insight.title || 'Insight'}</h3>
											<span class="badge badge-{insight.severity === 'high' ? 'danger' : insight.severity === 'medium' ? 'warning' : 'success'}">
												{insight.severity || 'low'} priority
											</span>
										</div>
									</div>
									<p class="insight-desc">{insight.description}</p>
									<div class="insight-date">{formatDate(insight.created_at)}</div>
								</div>
							{/each}
						</div>
					{:else}
						<div class="card empty-state">
							<div class="empty-icon">◈</div>
							<h3>No AI insights yet</h3>
							<p>Insights will appear here after a few wellness check-ins are recorded.</p>
						</div>
					{/if}
				</div>
			{/if}
		{/if}
	</main>
</div>

<style>
	/* ─── Shell ─────────────────────────────── */
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
		padding: 20px 16px;
		border-bottom: 1px solid var(--border);
		min-height: 64px;
	}

	.brand {
		display: flex;
		align-items: center;
		gap: 10px;
		overflow: hidden;
	}

	.brand-name {
		font-size: 1rem;
		font-weight: 800;
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
		font-size: 11px;
		color: var(--text-secondary);
		flex-shrink: 0;
		display: flex;
		align-items: center;
		justify-content: center;
	}

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

	.nav-item:hover { background: var(--bg); color: var(--text); }
	.nav-item.active { background: #dbeafe; color: var(--primary-dark); font-weight: 600; }

	.nav-icon { font-size: 16px; flex-shrink: 0; width: 20px; text-align: center; }
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
		width: 30px;
		height: 30px;
		border-radius: 50%;
		color: white;
		font-weight: 700;
		font-size: 13px;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}

	.patient-meta {
		display: flex;
		flex-direction: column;
		overflow: hidden;
		flex: 1;
	}

	.patient-name-sm {
		font-size: 13px;
		font-weight: 600;
		color: var(--text);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

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

	.user-avatar {
		width: 32px;
		height: 32px;
		border-radius: 50%;
		background: linear-gradient(135deg, var(--primary), var(--primary-dark));
		color: white;
		font-weight: 700;
		font-size: 13px;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}

	.user-details {
		display: flex;
		flex-direction: column;
		overflow: hidden;
		flex: 1;
	}

	.user-name {
		font-size: 13px;
		font-weight: 700;
		color: var(--text);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.user-role { font-size: 11px; color: var(--text-light); text-transform: capitalize; }

	.logout-btn {
		background: none;
		border: none;
		cursor: pointer;
		font-size: 16px;
		color: var(--text-light);
		padding: 2px;
	}

	.logout-btn:hover { color: var(--danger); }

	/* ─── Main ───────────────────────────────── */
	.main {
		margin-left: 260px;
		flex: 1;
		padding: 32px 36px;
		transition: margin-left 0.25s ease;
		max-width: calc(100vw - 260px);
	}

	/* ─── Header ─────────────────────────────── */
	.page-header {
		display: flex;
		align-items: flex-start;
		justify-content: space-between;
		margin-bottom: 28px;
	}

	.page-header h1 {
		font-size: 1.6rem;
		font-weight: 800;
		letter-spacing: -0.02em;
	}

	.page-subtitle { color: var(--text-secondary); font-size: 14px; margin-top: 4px; }

	.header-patient-badge {
		display: flex;
		align-items: center;
		gap: 12px;
		background: var(--card);
		border: 1px solid var(--border);
		border-radius: 12px;
		padding: 12px 16px;
	}

	.avatar-md {
		width: 44px;
		height: 44px;
		border-radius: 50%;
		color: white;
		font-weight: 800;
		font-size: 16px;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.score-value { font-size: 1.5rem; font-weight: 800; line-height: 1; }
	.score-sublabel { font-size: 11px; color: var(--text-secondary); font-weight: 600; text-transform: uppercase; letter-spacing: 0.04em; }

	/* ─── Stats Row ──────────────────────────── */
	.stats-row {
		display: grid;
		grid-template-columns: repeat(4, 1fr);
		gap: 16px;
		margin-bottom: 20px;
	}

	.stat-card {
		text-align: center;
		padding: 20px 16px;
	}

	.stat-icon { font-size: 20px; margin-bottom: 8px; }
	.stat-value { font-size: 2rem; font-weight: 800; line-height: 1; margin-bottom: 4px; }
	.stat-label { font-size: 12px; color: var(--text-secondary); font-weight: 600; text-transform: uppercase; letter-spacing: 0.04em; }

	/* ─── Score ──────────────────────────────── */
	.score-display {
		display: flex;
		align-items: center;
		gap: 32px;
	}

	.score-ring {
		width: 100px;
		height: 100px;
		border-radius: 50%;
		border: 8px solid var(--border);
		border-top-color: var(--color);
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}

	.score-number { font-size: 1.8rem; font-weight: 800; }

	.score-bar-wrapper { flex: 1; }

	.score-track {
		height: 14px;
		background: var(--border);
		border-radius: 7px;
		overflow: hidden;
		margin-bottom: 8px;
	}

	.score-fill {
		height: 100%;
		border-radius: 7px;
		transition: width 0.6s ease;
	}

	.score-markers {
		display: flex;
		justify-content: space-between;
		font-size: 11px;
		color: var(--text-light);
	}

	/* ─── Table ──────────────────────────────── */
	.checkin-table { display: flex; flex-direction: column; gap: 2px; }

	.table-head, .table-row {
		display: grid;
		grid-template-columns: 140px 70px 70px 70px 1fr;
		gap: 8px;
		align-items: center;
		padding: 10px 12px;
		border-radius: 8px;
		font-size: 13px;
	}

	.table-head { background: var(--bg); font-weight: 700; color: var(--text-secondary); font-size: 12px; text-transform: uppercase; letter-spacing: 0.04em; }
	.table-row { border-bottom: 1px solid var(--border); }
	.table-row:last-child { border: none; }

	.metric-chip {
		background: var(--bg);
		border-radius: 6px;
		padding: 2px 8px;
		font-weight: 700;
		text-align: center;
		font-size: 13px;
	}

	.note-preview { color: var(--text-secondary); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

	/* ─── Sliders ────────────────────────────── */
	.sliders-grid {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 20px;
	}

	.slider-card {
		background: var(--bg);
		border-radius: 12px;
		padding: 16px;
		border: 1px solid var(--border);
	}

	.slider-header {
		display: flex;
		align-items: center;
		gap: 8px;
		margin-bottom: 12px;
	}

	.slider-emoji { font-size: 18px; }
	.slider-name { font-weight: 600; font-size: 14px; flex: 1; }
	.slider-val { font-size: 1.4rem; font-weight: 800; color: var(--primary); min-width: 28px; text-align: right; }

	.range-input {
		width: 100%;
		height: 6px;
		border-radius: 3px;
		background: var(--border);
		outline: none;
		-webkit-appearance: none;
		cursor: pointer;
	}

	.range-input::-webkit-slider-thumb {
		-webkit-appearance: none;
		width: 20px;
		height: 20px;
		border-radius: 50%;
		background: var(--primary);
		cursor: pointer;
		box-shadow: 0 2px 6px rgba(59,130,246,0.4);
	}

	.slider-labels {
		display: flex;
		justify-content: space-between;
		margin-top: 6px;
		font-size: 11px;
		color: var(--text-light);
	}

	/* ─── Notes ──────────────────────────────── */
	.notes-list { display: flex; flex-direction: column; gap: 12px; }
	.note-card { padding: 20px 24px; }
	.note-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 10px; }
	.note-date { font-size: 12px; color: var(--text-light); }
	.note-content { color: var(--text-secondary); line-height: 1.7; font-size: 14px; }

	/* ─── Insights ───────────────────────────── */
	.insights-list { display: flex; flex-direction: column; gap: 12px; }
	.insight-card { padding: 20px 24px; }
	.insight-header { display: flex; align-items: flex-start; gap: 14px; margin-bottom: 10px; }
	.insight-icon { font-size: 24px; color: var(--secondary); flex-shrink: 0; }
	.insight-title { font-size: 1rem; font-weight: 700; margin-bottom: 4px; }
	.insight-desc { color: var(--text-secondary); font-size: 14px; line-height: 1.7; }
	.insight-date { font-size: 12px; color: var(--text-light); margin-top: 10px; }

	/* ─── States ─────────────────────────────── */
	.loading-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: 60vh;
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

	@keyframes spin { to { transform: rotate(360deg); } }

	.empty-state {
		text-align: center;
		padding: 60px 32px;
	}

	.empty-icon { font-size: 2.5rem; margin-bottom: 16px; }
	.empty-state h3 { margin-bottom: 8px; }
	.empty-state p { color: var(--text-secondary); }

	.empty-card {
		display: flex;
		align-items: center;
		justify-content: space-between;
		color: var(--text-secondary);
		font-size: 14px;
	}

	.mini-spinner {
		width: 14px;
		height: 14px;
		border: 2px solid rgba(255,255,255,0.3);
		border-top-color: white;
		border-radius: 50%;
		animation: spin 0.7s linear infinite;
		display: inline-block;
	}

	@media (max-width: 1100px) {
		.stats-row { grid-template-columns: repeat(2, 1fr); }
		.sliders-grid { grid-template-columns: 1fr; }
	}

	@media (max-width: 768px) {
		.sidebar { display: none; }
		.main { margin-left: 0; max-width: 100vw; padding: 20px; }
		.page-header { flex-direction: column; gap: 12px; }
		.header-patient-badge { align-self: stretch; }
		.table-head, .table-row { grid-template-columns: 1fr 1fr 1fr; }
		.table-head span:nth-child(n+4), .table-row span:nth-child(n+4) { display: none; }
	}
</style>
