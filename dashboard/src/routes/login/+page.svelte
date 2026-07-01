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
	let loading = false;
	let error = '';

	async function handleSubmit(e) {
		e.preventDefault();
		loading = true;
		error = '';

		try {
			let result;
			if (mode === 'login') {
				result = await login(email, password);
			} else {
				result = await register(email, password, firstName, lastName, role);
			}
			auth.login(result.token, result.user);
			addNotification(`Welcome back, ${result.user.firstName || result.user.email}!`, 'success');
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
				<div class="brand-icon">
					<svg width="36" height="36" viewBox="0 0 36 36" fill="none">
						<rect width="36" height="36" rx="10" fill="white" fill-opacity="0.15"/>
						<path d="M18 8 L18 28 M8 18 L28 18" stroke="white" stroke-width="3.5" stroke-linecap="round"/>
					</svg>
				</div>
				<span class="brand-name">CareBridge</span>
			</div>

			<div class="hero-text">
				<h1>Healthcare coordination, <em>reimagined</em></h1>
				<p>AI-powered insights, real-time patient monitoring, and seamless team communication — all in one place.</p>
			</div>

			<div class="feature-list">
				{#each ['Real-time wellness tracking', 'AI trend detection & alerts', 'Medication & appointment management', 'Collaborative care notes'] as feat}
					<div class="feature-item">
						<div class="feature-check">✓</div>
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

			<form on:submit={handleSubmit} novalidate>
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
								{ value: 'patient', label: 'Patient' },
								{ value: 'family', label: 'Family Member' },
								{ value: 'organization', label: 'Organization Admin' }
							]}
						/>
					</div>
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
		padding: 60px 56px;
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
		gap: 12px;
		margin-bottom: 56px;
	}

	.brand-name {
		font-size: 1.4rem;
		font-weight: 800;
		color: white;
		letter-spacing: -0.02em;
	}

	.hero-text h1 {
		font-size: 2.4rem;
		font-weight: 800;
		color: white;
		line-height: 1.2;
		margin-bottom: 20px;
		letter-spacing: -0.03em;
	}

	.hero-text h1 em {
		font-style: normal;
		opacity: 0.85;
	}

	.hero-text p {
		font-size: 1.05rem;
		color: rgba(255,255,255,0.8);
		line-height: 1.7;
		margin-bottom: 40px;
	}

	.feature-list {
		display: flex;
		flex-direction: column;
		gap: 14px;
	}

	.feature-item {
		display: flex;
		align-items: center;
		gap: 12px;
		color: rgba(255,255,255,0.9);
		font-size: 0.95rem;
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
		font-size: 11px;
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
		font-size: 1.6rem;
		font-weight: 800;
		margin-bottom: 6px;
		letter-spacing: -0.02em;
	}

	.form-header p {
		color: var(--text-secondary);
		font-size: 0.95rem;
	}

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
