<script>
	import { goto } from '$app/navigation';
	import { auth, addNotification } from '$lib/stores';
	import { login, register } from '$lib/api';
	import CustomSelect from '$lib/components/CustomSelect.svelte';

	let mode = 'login'; // 'login' | 'register'
	let email = '';
	let password = '';
	let firstName = '';
	let lastName = '';
	let role = 'caregiver';
	let joinCode = '';
	let loading = false;
	let error = '';

	// Demo dropdown state
	let selectedDemoRole = '';
	let demoOpen = false;

	const demoOptions = [
		{ value: 'caregiver', label: 'Caregiver', desc: 'Full patient management dashboard' },
		{ value: 'family', label: 'Family Member', desc: 'View a linked patient' },
		{ value: 'organization', label: 'Organization', desc: 'Multi-patient coordination' }
	];

	async function demoLogin() {
		if (!selectedDemoRole) return;
		loading = true;
		error = '';
		demoOpen = false;
		try {
			const demoEmail = selectedDemoRole + '@demo.com';
			let result;
			try {
				result = await login(demoEmail, 'demo1234');
			} catch (e) {
				const label = demoOptions.find(o => o.value === selectedDemoRole)?.label || selectedDemoRole;
				result = await register(demoEmail, 'demo1234', 'Demo', label, selectedDemoRole);
			}
			auth.login(result.token, result.user);
			addNotification(`Signed in as Demo ${selectedDemoRole}!`, 'success');
			goto('/dashboard');
		} catch (err) {
			error = err.message;
		} finally {
			loading = false;
		}
	}

	async function handleSubmit(e) {
		e.preventDefault();
		loading = true;
		error = '';

		try {
			let result;
			if (mode === 'login') {
				result = await login(email, password);
			} else {
				result = await register(email, password, firstName, lastName, role, role === 'family' && joinCode ? joinCode : null);
			}
			auth.login(result.token, result.user);
			addNotification(`Welcome, ${result.user.firstName || result.user.email}!`, 'success');
			goto('/dashboard');
		} catch (err) {
			error = err.message;
		} finally {
			loading = false;
		}
	}

	function switchMode(m) {
		mode = m;
		error = '';
	}
</script>

<svelte:head>
	<title>Sign In — CareBridge</title>
	<meta name="description" content="Sign in to CareBridge, the AI-powered healthcare coordination platform." />
</svelte:head>

<div class="auth-page">
	<!-- Left panel -->
	<div class="hero-panel">
		<div class="hero-content">
			<div class="brand">
				<img src="/logo.png" alt="CareBridge Logo" class="brand-logo" />
				<span class="brand-name">CareBridge</span>
			</div>

			<div class="hero-text">
				<h1>Healthcare coordination, <em>reimagined</em></h1>
				<p>AI-powered insights, real-time patient monitoring, and seamless team communication — all in one place.</p>
			</div>

			<div class="feature-list">
				{#each ['Real-time wellness tracking', 'AI trend detection & alerts', 'Medication & appointment management', 'Collaborative care notes'] as feat}
					<div class="feature-item">
						<div class="feature-check">
							<svg width="11" height="11" viewBox="0 0 12 12" fill="none">
								<path d="M2 6l3 3 5-5" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
							</svg>
						</div>
						<span>{feat}</span>
					</div>
				{/each}
			</div>
		</div>

		<div class="hero-blur-1"></div>
		<div class="hero-blur-2"></div>
	</div>

	<!-- Right panel (form) -->
	<div class="form-panel">
		<div class="form-card">
			<div class="form-header">
				<h2>{mode === 'login' ? 'Welcome back' : 'Create account'}</h2>
				<p>{mode === 'login' ? 'Sign in to your CareBridge dashboard' : 'Start coordinating care today'}</p>
			</div>

			<!-- Demo Quick Login -->
			<div class="demo-logins">
				<p class="demo-label">Quick Demo Access</p>
				<div class="demo-row">
					<!-- svelte-ignore a11y-click-events-have-key-events -->
					<!-- svelte-ignore a11y-no-static-element-interactions -->
					<div class="demo-select-wrapper" on:click={() => demoOpen = !demoOpen}>
						<div class="demo-select-trigger" class:open={demoOpen}>
							{#if selectedDemoRole}
								<span class="demo-selected">{demoOptions.find(o => o.value === selectedDemoRole)?.label}</span>
							{:else}
								<span class="demo-placeholder">Select a demo role…</span>
							{/if}
							<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" class="chevron" class:rotated={demoOpen}>
								<polyline points="6 9 12 15 18 9"/>
							</svg>
						</div>
						{#if demoOpen}
							<div class="demo-dropdown">
								{#each demoOptions as opt}
									<!-- svelte-ignore a11y-click-events-have-key-events -->
									<div
										class="demo-option {selectedDemoRole === opt.value ? 'selected' : ''}"
										on:click|stopPropagation={() => { selectedDemoRole = opt.value; demoOpen = false; }}
									>
										<span class="demo-opt-label">{opt.label}</span>
										<span class="demo-opt-desc">{opt.desc}</span>
									</div>
								{/each}
							</div>
						{/if}
					</div>
					<button
						class="btn btn-primary btn-sm demo-signin-btn"
						on:click={demoLogin}
						disabled={!selectedDemoRole || loading}
					>
						Sign In
					</button>
				</div>
			</div>

			<!-- Tab switcher -->
			<div class="tabs" role="tablist">
				<button
					class="tab {mode === 'login' ? 'active' : ''}"
					role="tab"
					id="tab-login"
					aria-selected={mode === 'login'}
					on:click={() => switchMode('login')}
				>Sign In</button>
				<button
					class="tab {mode === 'register' ? 'active' : ''}"
					role="tab"
					id="tab-register"
					aria-selected={mode === 'register'}
					on:click={() => switchMode('register')}
				>Register</button>
			</div>

			{#if error}
				<div class="alert alert-error" role="alert">
					<span>⚠</span> {error}
				</div>
			{/if}

			<form on:submit={handleSubmit}>
				{#if mode === 'register'}
					<div class="name-row">
						<div class="form-group">
							<label for="firstName">First Name</label>
							<input
								id="firstName"
								type="text"
								bind:value={firstName}
								placeholder="Jane"
								autocomplete="given-name"
								required
							/>
						</div>
						<div class="form-group">
							<label for="lastName">Last Name</label>
							<input
								id="lastName"
								type="text"
								bind:value={lastName}
								placeholder="Smith"
								autocomplete="family-name"
								required
							/>
						</div>
					</div>

					<div class="form-group">
						<label for="role">Role</label>
						<CustomSelect
							id="role"
							bind:value={role}
							options={[
								{ value: 'caregiver', label: 'Caregiver' },
								{ value: 'family', label: 'Family Member' },
								{ value: 'organization', label: 'Organization Admin' }
							]}
						/>
					</div>

					{#if role === 'family'}
						<div class="form-group">
							<label for="joinCode">Family Join Code <span class="optional">(optional)</span></label>
							<input
								id="joinCode"
								type="text"
								bind:value={joinCode}
								placeholder="Enter code from your family member's care team"
								autocomplete="off"
								style="text-transform: uppercase; letter-spacing: 0.1em;"
							/>
							<p class="field-hint">Don't have a code? You can link to your family member after signing in.</p>
						</div>
					{/if}
				{/if}

				<div class="form-group">
					<label for="email">Email Address</label>
					<input
						id="email"
						type="email"
						bind:value={email}
						placeholder="you@example.com"
						autocomplete="email"
						required
					/>
				</div>

				<div class="form-group">
					<label for="password">Password</label>
					<input
						id="password"
						type="password"
						bind:value={password}
						placeholder="••••••••"
						autocomplete={mode === 'login' ? 'current-password' : 'new-password'}
						required
					/>
				</div>

				<button
					type="submit"
					class="btn btn-primary submit-btn"
					disabled={loading}
					id="auth-submit-btn"
				>
					{#if loading}
						<span class="spinner"></span> {mode === 'login' ? 'Signing in…' : 'Creating account…'}
					{:else}
						{mode === 'login' ? 'Sign In' : 'Create Account'} →
					{/if}
				</button>

				<div class="divider">
					<span>or</span>
				</div>

				<button type="button" class="btn btn-secondary google-btn" on:click={() => addNotification('Google Sign-In coming soon!', 'info')}>
					<svg width="18" height="18" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
						<path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
						<path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
						<path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/>
						<path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
					</svg>
					Sign in with Google
				</button>
			</form>

			<p class="switch-hint">
				{mode === 'login' ? "Don't have an account?" : 'Already have an account?'}
				<button class="link-btn" on:click={() => switchMode(mode === 'login' ? 'register' : 'login')}>
					{mode === 'login' ? 'Register' : 'Sign in'}
				</button>
			</p>
		</div>
	</div>
</div>

<style>
	.auth-page {
		min-height: 100vh;
		display: grid;
		grid-template-columns: 1fr 1fr;
	}

	/* ─── Hero Panel ─────────────────────────── */
	.hero-panel {
		background: linear-gradient(145deg, #1d4ed8 0%, #3b82f6 50%, #06b6d4 100%);
		padding: 64px 64px;
		display: flex;
		align-items: center;
		position: relative;
		overflow: hidden;
	}

	.hero-blur-1 {
		position: absolute;
		width: 400px;
		height: 400px;
		border-radius: 50%;
		background: rgba(255,255,255,0.07);
		top: -100px;
		right: -100px;
	}

	.hero-blur-2 {
		position: absolute;
		width: 300px;
		height: 300px;
		border-radius: 50%;
		background: rgba(255,255,255,0.05);
		bottom: -80px;
		left: -80px;
	}

	.hero-content {
		position: relative;
		z-index: 1;
		color: white;
	}

	.brand {
		display: flex;
		align-items: center;
		gap: 18px;
		margin-bottom: 64px;
	}

	.brand-logo {
		width: 68px;
		height: 68px;
		border-radius: 18px;
		object-fit: contain;
		background: white;
		padding: 6px;
		box-shadow: 0 4px 20px rgba(0,0,0,0.15);
	}

	.brand-name {
		font-family: Palatino, 'Palatino Linotype', 'Book Antiqua', Georgia, serif;
		font-size: 2.4rem;
		font-weight: 700;
		color: white;
		letter-spacing: -0.02em;
		line-height: 1;
	}

	.hero-text h1 {
		font-size: 3.2rem;
		font-weight: 700;
		color: white;
		line-height: 1.15;
		margin-bottom: 24px;
		letter-spacing: -0.02em;
	}

	.hero-text h1 em {
		font-style: italic;
		opacity: 0.88;
	}

	.hero-text p {
		font-size: 1.1rem;
		color: rgba(255,255,255,0.8);
		line-height: 1.75;
		margin-bottom: 44px;
	}

	.feature-list {
		display: flex;
		flex-direction: column;
		gap: 16px;
	}

	.feature-item {
		display: flex;
		align-items: center;
		gap: 12px;
		color: rgba(255,255,255,0.92);
		font-size: 1rem;
		font-weight: 500;
	}

	.feature-check {
		width: 22px;
		height: 22px;
		border-radius: 50%;
		background: rgba(255,255,255,0.2);
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}

	/* ─── Form Panel ─────────────────────────── */
	.form-panel {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 48px 40px;
		background: var(--bg);
	}

	.form-card {
		width: 100%;
		max-width: 440px;
		background: var(--card);
		border-radius: 20px;
		padding: 40px;
		box-shadow: var(--shadow-lg);
		border: 1px solid var(--border);
	}

	.form-header {
		margin-bottom: 28px;
	}

	.form-header h2 {
		font-size: 1.65rem;
		font-weight: 700;
		margin-bottom: 6px;
		letter-spacing: -0.02em;
	}

	.form-header p {
		color: var(--text-secondary);
		font-size: 0.95rem;
	}

	/* ─── Demo Section ───────────────────────── */
	.demo-logins {
		margin-bottom: 24px;
		padding: 16px;
		background: rgba(59, 130, 246, 0.04);
		border: 1px dashed rgba(59, 130, 246, 0.4);
		border-radius: 12px;
	}

	.demo-label {
		font-size: 11px;
		color: var(--primary);
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.07em;
		margin-bottom: 10px;
	}

	.demo-row {
		display: flex;
		gap: 8px;
		align-items: stretch;
	}

	.demo-select-wrapper {
		flex: 1;
		position: relative;
		cursor: pointer;
	}

	.demo-select-trigger {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 8px 12px;
		background: var(--card);
		border: 1.5px solid var(--border);
		border-radius: 8px;
		font-size: 13px;
		transition: border-color 0.15s;
		user-select: none;
	}

	.demo-select-trigger.open {
		border-color: var(--primary);
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.demo-placeholder { color: var(--text-light); }
	.demo-selected { color: var(--text); font-weight: 600; }

	.chevron { color: var(--text-light); transition: transform 0.2s; flex-shrink: 0; }
	.chevron.rotated { transform: rotate(180deg); }

	.demo-dropdown {
		position: absolute;
		top: calc(100% + 4px);
		left: 0;
		right: 0;
		background: var(--card);
		border: 1.5px solid var(--border);
		border-radius: 10px;
		box-shadow: var(--shadow);
		z-index: 50;
		overflow: hidden;
	}

	.demo-option {
		padding: 10px 14px;
		cursor: pointer;
		transition: background 0.12s;
	}

	.demo-option:hover { background: var(--bg); }
	.demo-option.selected { background: #eff6ff; }

	.demo-opt-label {
		display: block;
		font-size: 13px;
		font-weight: 600;
		color: var(--text);
	}

	.demo-opt-desc {
		display: block;
		font-size: 11px;
		color: var(--text-light);
		margin-top: 1px;
	}

	.demo-signin-btn {
		flex-shrink: 0;
		white-space: nowrap;
	}

	/* ─── Tabs ───────────────────────────────── */
	.tabs {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 6px;
		background: var(--bg);
		padding: 4px;
		border-radius: 10px;
		margin-bottom: 24px;
	}

	.tab {
		padding: 10px;
		border: none;
		border-radius: 8px;
		font-size: 14px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		background: transparent;
		color: var(--text-secondary);
	}

	.tab.active {
		background: var(--card);
		color: var(--text);
		box-shadow: var(--shadow-sm);
	}

	.name-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 12px;
	}

	.optional {
		font-weight: 400;
		color: var(--text-light);
		font-size: 12px;
	}

	.field-hint {
		font-size: 12px;
		color: var(--text-light);
		margin-top: 6px;
	}

	.submit-btn {
		width: 100%;
		justify-content: center;
		margin-top: 8px;
		padding: 13px;
		font-size: 15px;
	}

	.spinner {
		width: 16px;
		height: 16px;
		border: 2px solid rgba(255,255,255,0.3);
		border-top-color: white;
		border-radius: 50%;
		animation: spin 0.7s linear infinite;
		display: inline-block;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.divider {
		display: flex;
		align-items: center;
		text-align: center;
		margin: 20px 0;
		color: var(--text-secondary);
		font-size: 13px;
	}

	.divider::before, .divider::after {
		content: '';
		flex: 1;
		border-bottom: 1px solid var(--border);
	}

	.divider span {
		padding: 0 10px;
	}

	.google-btn {
		width: 100%;
		justify-content: center;
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 12px;
		background: white;
		border: 1px solid var(--border);
		color: var(--text);
		font-weight: 500;
	}

	.switch-hint {
		text-align: center;
		margin-top: 20px;
		font-size: 14px;
		color: var(--text-secondary);
	}

	.link-btn {
		background: none;
		border: none;
		color: var(--primary);
		font-weight: 600;
		cursor: pointer;
		font-size: 14px;
		padding: 0;
		margin-left: 4px;
	}

	.link-btn:hover {
		text-decoration: underline;
	}

	@media (max-width: 900px) {
		.auth-page {
			grid-template-columns: 1fr;
		}
		.hero-panel {
			display: none;
		}
		.form-panel {
			padding: 32px 20px;
		}
	}
</style>
