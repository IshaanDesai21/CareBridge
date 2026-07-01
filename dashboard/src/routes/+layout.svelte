<script>
	import '../app.css';
	import { notifications } from '$lib/stores';
</script>

<slot />

<!-- Global Notification Toast -->
{#each $notifications as notif (notif.id)}
	<div class="toast toast-{notif.type}" role="alert" aria-live="polite">
		<span class="toast-icon">
			{#if notif.type === 'success'}✓{:else if notif.type === 'error'}✕{:else}ℹ{/if}
		</span>
		{notif.message}
	</div>
{/each}

<style>
	.toast {
		position: fixed;
		bottom: 24px;
		right: 24px;
		padding: 14px 20px;
		border-radius: 12px;
		font-size: 14px;
		font-weight: 500;
		display: flex;
		align-items: center;
		gap: 10px;
		box-shadow: 0 8px 24px rgba(0,0,0,0.15);
		animation: slideIn 0.3s ease;
		z-index: 9999;
		max-width: 380px;
	}

	.toast-success { background: #065f46; color: white; }
	.toast-error   { background: #991b1b; color: white; }
	.toast-warning { background: #92400e; color: white; }
	.toast-info    { background: #1e3a8a; color: white; }

	.toast-icon {
		width: 20px;
		height: 20px;
		border-radius: 50%;
		background: rgba(255,255,255,0.2);
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 11px;
		font-weight: 700;
		flex-shrink: 0;
	}

	@keyframes slideIn {
		from { opacity: 0; transform: translateX(20px); }
		to   { opacity: 1; transform: translateX(0); }
	}
</style>
