<script>
	import { goto } from '$app/navigation';
	import { auth } from '$lib/stores';
	import { login, register } from '$lib/api';
	
	let isLogin = true;
	let email = '';
	let password = '';
	let firstName = '';
	let lastName = '';
	let error = '';
	let loading = false;
	
	async function handleLogin() {
		loading = true;
		error = '';
		
		try {
			const result = await login(email, password);
			auth.login(result.token, result.user);
			goto('/dashboard');
		} catch (err) {
			error = err.message;
		} finally {
			loading = false;
		}
	}
	
	async function handleRegister() {
		loading = true;
		error = '';
		
		try {
			const result = await register(email, password, firstName, lastName);
			auth.login(result.token, result.user);
			goto('/dashboard');
		} catch (err) {
			error = err.message;
		} finally {
			loading = false;
		}
	}
	
	function handleSubmit(e) {
		e.preventDefault();
		if (isLogin) {
			handleLogin();
		} else {
			handleRegister();
		}
	}
</script>

<div class="auth-container">
	<div class="auth-card">
		<div class="header">
			<h1>🏥 CareBridge</h1>
			<p>Healthcare Coordination Platform</p>
		</div>
		
		<div class="tabs">
			<button 
				class="tab {isLogin ? 'active' : ''}" 
				on:click={() => { isLogin = true; error = ''; }}
			>
				Login
			</button>
			<button 
				class="tab {!isLogin ? 'active' : ''}" 
				on:click={() => { isLogin = false; error = ''; }}
			>
				Register
			</button>
		</div>
		
		{#if error}
			<div class="alert alert-error">{error}</div>
		{/if}
		
		<form on:submit={handleSubmit}>
			{#if !isLogin}
				<div class="form-group">
					<label for="firstName">First Name</label>
					<input 
						type="text" 
						id="firstName" 
						bind:value={firstName}
						placeholder="John"
						required
					/>
				</div>
				
				<div class="form-group">
					<label for="lastName">Last Name</label>
					<input 
						type="text" 
						id="lastName" 
						bind:value={lastName}
						placeholder="Doe"
						required
					/>
				</div>
			{/if}
			
			<div class="form-group">
				<label for="email">Email</label>
				<input 
					type="email" 
					id="email" 
					bind:value={email}
					placeholder="your@email.com"
					required
				/>
			</div>
			
			<div class="form-group">
				<label for="password">Password</label>
				<input 
					type="password" 
					id="password" 
					bind:value={password}
					placeholder="••••••••"
					required
				/>
			</div>
			
			<button type="submit" class="btn btn-primary" disabled={loading} style="width: 100%;">
				{#if loading}
					Loading...
				{:else}
					{isLogin ? 'Sign In' : 'Create Account'}
				{/if}
			</button>
		</form>
	</div>
</div>

<style>
	.auth-container {
		min-height: 100vh;
		display: flex;
		align-items: center;
		justify-content: center;
		background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
		padding: 20px;
	}
	
	.auth-card {
		background: white;
		border-radius: 20px;
		padding: 48px;
		width: 100%;
		max-width: 480px;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
	}
	
	.header {
		text-align: center;
		margin-bottom: 32px;
	}
	
	.header h1 {
		font-size: 2.5rem;
		background: linear-gradient(135deg, var(--primary), var(--primary-dark));
		-webkit-background-clip: text;
		-webkit-text-fill-color: transparent;
		background-clip: text;
		margin-bottom: 8px;
	}
	
	.header p {
		color: var(--text-light);
		font-size: 1.1rem;
	}
	
	.tabs {
		display: flex;
		gap: 12px;
		margin-bottom: 32px;
	}
	
	.tab {
		flex: 1;
		padding: 12px;
		border: none;
		background: var(--bg);
		border-radius: 10px;
		font-size: 16px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
		color: var(--text);
	}
	
	.tab.active {
		background: linear-gradient(135deg, var(--primary), var(--primary-dark));
		color: white;
	}
	
	.tab:hover:not(.active) {
		background: #e5e7eb;
	}
</style>
