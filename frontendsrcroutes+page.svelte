<script>
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { auth } from '$lib/stores';
	
	let isAuthenticated = false;
	
	onMount(() => {
		const unsubscribe = auth.subscribe(state => {
			isAuthenticated = state.isAuthenticated;
			if (!isAuthenticated) {
				goto('/login');
			} else {
				goto('/dashboard');
			}
		});
		
		return unsubscribe;
	});
</script>

<div class="container" style="min-height: 100vh; display: flex; align-items: center; justify-content: center;">
	<div class="card" style="text-align: center;">
		<h1>🏥 CareBridge</h1>
		<p style="color: var(--text-light); font-size: 1.2rem; margin-top: 16px;">
			Healthcare Coordination Platform
		</p>
		<p style="margin-top: 32px;">Loading...</p>
	</div>
</div>

<style>
	h1 {
		background: linear-gradient(135deg, var(--primary), var(--primary-dark));
		-webkit-background-clip: text;
		-webkit-text-fill-color: transparent;
		background-clip: text;
	}
</style>
