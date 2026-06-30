<script>
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { auth } from '$lib/stores';
	import { getPatients, submitWellnessCheckin } from '$lib/api';
	
	let user = null;
	let patients = [];
	let patientId = null;
	let wellnessScore = 75;
	let loading = true;
	let message = '';
	let messageType = '';
	
	// Wellness form data
	let energy = 5;
	let mood = 5;
	let pain = 5;
	let notes = '';
	
	onMount(async () => {
		const unsubscribe = auth.subscribe(async state => {
			if (!state.isAuthenticated) {
				goto('/login');
				return;
			}
			
			user = state.user;
			await loadPatients();
			loading = false;
		});
		
		return unsubscribe;
	});
	
	async function loadPatients() {
		try {
			const result = await getPatients();
			patients = result.patients || [];
			
			if (patients.length > 0) {
				patientId = patients[0].id;
				wellnessScore = patients[0].wellness_score || 75;
			}
		} catch (err) {
			console.error('Failed to load patients:', err);
		}
	}
	
	async function handleSubmitCheckin() {
		if (!patientId) {
			showMessage('Please wait while we load your profile...', 'error');
			return;
		}
		
		try {
			const result = await submitWellnessCheckin({
				patientId,
				energy,
				mood,
				pain,
				notes
			});
			
			wellnessScore = result.wellnessScore;
			showMessage('Check-in submitted successfully! 🎉', 'success');
			notes = '';
			await loadPatients();
		} catch (err) {
			showMessage(err.message, 'error');
		}
	}
	
	function showMessage(msg, type) {
		message = msg;
		messageType = type;
		setTimeout(() => {
			message = '';
		}, 3000);
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
</script>

<div class="dashboard">
	<nav class="navbar">
		<div class="container">
			<div class="nav-content">
				<h2>🏥 CareBridge</h2>
				<div class="nav-actions">
					<span class="user-name">Welcome, {user?.firstName || user?.email}!</span>
					<button class="btn btn-secondary" on:click={handleLogout}>Logout</button>
				</div>
			</div>
		</div>
	</nav>
	
	<div class="container">
		{#if loading}
			<div class="card">
				<p style="text-align: center;">Loading...</p>
			</div>
		{:else}
			{#if message}
				<div class="alert alert-{messageType}">{message}</div>
			{/if}
			
			<!-- Wellness Score Card -->
			<div class="card score-card">
				<h2>Your Wellness Score</h2>
				<div 
					class="wellness-score" 
					style="color: {getScoreColor(wellnessScore)}"
				>
					{wellnessScore}
				</div>
				<div class="score-bar">
					<div 
						class="score-fill" 
						style="width: {wellnessScore}%; background: {getScoreColor(wellnessScore)}"
					></div>
				</div>
				<p class="score-description">
					{#if wellnessScore >= 80}
						🌟 Excellent! Your health is looking great.
					{:else if wellnessScore >= 60}
						👍 Good! Keep maintaining your wellness routine.
					{:else}
						💙 We're here for you. Consider reaching out to your care team.
					{/if}
				</p>
			</div>
			
			<!-- Wellness Check-in Form -->
			<div class="card">
				<h2>Daily Wellness Check-In</h2>
				<p style="color: var(--text-light); margin-bottom: 24px;">
					Take a moment to track how you're feeling today
				</p>
				
				<div class="slider-group">
					<div class="slider-label">
						<span>⚡ Energy Level</span>
						<span class="value">{energy}</span>
					</div>
					<input type="range" min="1" max="10" bind:value={energy} />
					<div class="slider-hint">
						<span>Low</span>
						<span>High</span>
					</div>
				</div>
				
				<div class="slider-group">
					<div class="slider-label">
						<span>😊 Mood</span>
						<span class="value">{mood}</span>
					</div>
					<input type="range" min="1" max="10" bind:value={mood} />
					<div class="slider-hint">
						<span>Low</span>
						<span>High</span>
					</div>
				</div>
				
				<div class="slider-group">
					<div class="slider-label">
						<span>🤕 Pain Level</span>
						<span class="value">{pain}</span>
					</div>
					<input type="range" min="1" max="10" bind:value={pain} />
					<div class="slider-hint">
						<span>None</span>
						<span>Severe</span>
					</div>
				</div>
				
				<div class="form-group">
					<label for="notes">📝 Notes (optional)</label>
					<textarea 
						id="notes" 
						bind:value={notes}
						placeholder="How are you feeling today? Any concerns or observations?"
						rows="4"
					></textarea>
				</div>
				
				<button class="btn btn-primary" on:click={handleSubmitCheckin}>
					Submit Check-In
				</button>
			</div>
			
			<!-- Patients List -->
			{#if patients.length > 0}
				<div class="card">
					<h2>All Patients</h2>
					<div class="patients-grid">
						{#each patients as patient}
							<div class="patient-card">
								<div class="patient-info">
									<div class="patient-avatar">
										{patient.first_name?.charAt(0) || patient.email?.charAt(0)}
									</div>
									<div>
										<h3>{patient.first_name} {patient.last_name}</h3>
										<p class="patient-email">{patient.email}</p>
									</div>
								</div>
								<div class="patient-score">
									<div 
										class="score-badge" 
										style="background: {getScoreColor(patient.wellness_score)}"
									>
										{patient.wellness_score}
									</div>
									<span class="score-label">Wellness</span>
								</div>
							</div>
						{/each}
					</div>
				</div>
			{/if}
		{/if}
	</div>
</div>

<style>
	.dashboard {
		min-height: 100vh;
		background: var(--bg);
	}
	
	.navbar {
		background: white;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
		padding: 20px 0;
		margin-bottom: 32px;
	}
	
	.nav-content {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}
	
	.nav-content h2 {
		margin: 0;
		background: linear-gradient(135deg, var(--primary), var(--primary-dark));
		-webkit-background-clip: text;
		-webkit-text-fill-color: transparent;
		background-clip: text;
	}
	
	.nav-actions {
		display: flex;
		align-items: center;
		gap: 20px;
	}
	
	.user-name {
		color: var(--text-light);
		font-weight: 500;
	}
	
	.score-card {
		text-align: center;
		background: linear-gradient(135deg, #667eea15, #764ba215);
	}
	
	.wellness-score {
		font-size: 5rem;
		font-weight: 800;
		margin: 24px 0;
		line-height: 1;
	}
	
	.score-bar {
		height: 12px;
		background: var(--border);
		border-radius: 6px;
		overflow: hidden;
		margin: 24px 0;
	}
	
	.score-fill {
		height: 100%;
		transition: width 0.3s ease;
		border-radius: 6px;
	}
	
	.score-description {
		font-size: 1.1rem;
		color: var(--text-light);
	}
	
	.slider-group {
		margin-bottom: 32px;
	}
	
	.slider-label {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 12px;
		font-weight: 600;
	}
	
	.slider-label .value {
		font-size: 1.5rem;
		color: var(--primary);
	}
	
	input[type="range"] {
		width: 100%;
		height: 8px;
		border-radius: 4px;
		background: var(--border);
		outline: none;
		-webkit-appearance: none;
	}
	
	input[type="range"]::-webkit-slider-thumb {
		-webkit-appearance: none;
		appearance: none;
		width: 24px;
		height: 24px;
		border-radius: 50%;
		background: var(--primary);
		cursor: pointer;
		box-shadow: 0 2px 8px rgba(102, 126, 234, 0.3);
	}
	
	input[type="range"]::-moz-range-thumb {
		width: 24px;
		height: 24px;
		border-radius: 50%;
		background: var(--primary);
		cursor: pointer;
		border: none;
		box-shadow: 0 2px 8px rgba(102, 126, 234, 0.3);
	}
	
	.slider-hint {
		display: flex;
		justify-content: space-between;
		margin-top: 8px;
		font-size: 0.9rem;
		color: var(--text-light);
	}
	
	.patients-grid {
		display: grid;
		gap: 16px;
	}
	
	.patient-card {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 20px;
		background: var(--bg);
		border-radius: 12px;
		transition: transform 0.2s;
	}
	
	.patient-card:hover {
		transform: translateY(-2px);
	}
	
	.patient-info {
		display: flex;
		align-items: center;
		gap: 16px;
	}
	
	.patient-avatar {
		width: 56px;
		height: 56px;
		border-radius: 50%;
		background: linear-gradient(135deg, var(--primary), var(--primary-dark));
		color: white;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 1.5rem;
		font-weight: 700;
		text-transform: uppercase;
	}
	
	.patient-card h3 {
		margin: 0;
		font-size: 1.2rem;
	}
	
	.patient-email {
		color: var(--text-light);
		margin: 4px 0 0 0;
	}
	
	.patient-score {
		text-align: center;
	}
	
	.score-badge {
		width: 64px;
		height: 64px;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 1.5rem;
		font-weight: 700;
		color: white;
		margin: 0 auto 8px;
	}
	
	.score-label {
		font-size: 0.9rem;
		color: var(--text-light);
	}
	
	@media (max-width: 768px) {
		.nav-content {
			flex-direction: column;
			gap: 16px;
		}
		
		.wellness-score {
			font-size: 3.5rem;
		}
		
		.patient-card {
			flex-direction: column;
			text-align: center;
			gap: 16px;
		}
	}
</style>
