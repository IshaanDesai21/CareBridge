<script>
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { auth } from '$lib/stores';

	onMount(() => {
		const unsub = auth.subscribe(state => {
			if (state.isAuthenticated) {
				goto('/dashboard');
			} else {
				goto('/login');
			}
		});
		return unsub;
	});
</script>

<div class="splash">
	<div class="logo">
		<div class="logo-icon">
			<svg width="40" height="40" viewBox="0 0 40 40" fill="none">
				<rect width="40" height="40" rx="12" fill="url(#grad)"/>
				<path d="M20 10 L20 30 M10 20 L30 20" stroke="white" stroke-width="4" stroke-linecap="round"/>
				<defs>
					<linearGradient id="grad" x1="0" y1="0" x2="40" y2="40" gradientUnits="userSpaceOnUse">
						<stop stop-color="#3b82f6"/>
						<stop offset="1" stop-color="#1d4ed8"/>
					</linearGradient>
				</defs>
			</svg>
		</div>
		<span>CareBridge</span>
	</div>
	<p>Loading...</p>
</div>

<style>
	.splash {
		min-height: 100vh;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 16px;
		background: var(--bg);
	}

	.logo {
		display: flex;
		align-items: center;
		gap: 12px;
		font-size: 1.8rem;
		font-weight: 800;
		color: var(--text);
	}

	p {
		color: var(--text-light);
		font-size: 14px;
	}
</style>
