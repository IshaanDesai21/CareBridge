<script>
	import { createEventDispatcher, onMount } from 'svelte';
	
	export let options = []; // Array of {value, label} or strings
	export let value = '';
	export let placeholder = 'Select an option...';
	export let id = '';

	const dispatch = createEventDispatcher();
	
	let isOpen = false;
	let dropdownRef;

	// Normalize options to {value, label} objects
	$: normalizedOptions = options.map(opt => 
		typeof opt === 'string' ? { value: opt, label: opt } : opt
	);

	$: selectedLabel = normalizedOptions.find(o => o.value === value)?.label || placeholder;

	function toggleDropdown() {
		isOpen = !isOpen;
	}

	function selectOption(opt) {
		value = opt.value;
		isOpen = false;
		dispatch('change', value);
	}

	// Close on click outside
	function handleClickOutside(event) {
		if (isOpen && dropdownRef && !dropdownRef.contains(event.target)) {
			isOpen = false;
		}
	}

	onMount(() => {
		document.addEventListener('click', handleClickOutside);
		return () => {
			document.removeEventListener('click', handleClickOutside);
		};
	});
</script>

<div class="custom-select" bind:this={dropdownRef} {id}>
	<button type="button" class="select-trigger" class:open={isOpen} on:click={toggleDropdown}>
		<span class="selected-text" class:placeholder={!value}>{selectedLabel}</span>
		<span class="chevron">
			<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
				<polyline points="6 9 12 15 18 9"></polyline>
			</svg>
		</span>
	</button>

	{#if isOpen}
		<div class="options-container">
			{#each normalizedOptions as opt (opt.value)}
				<button 
					type="button"
					class="option" 
					class:selected={value === opt.value}
					on:click={() => selectOption(opt)}
				>
					{opt.label}
					{#if value === opt.value}
						<span class="check">✓</span>
					{/if}
				</button>
			{/each}
		</div>
	{/if}
</div>

<style>
	.custom-select {
		position: relative;
		width: 100%;
		font-family: 'Inter', sans-serif;
	}

	.select-trigger {
		width: 100%;
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 12px 16px;
		background: rgba(255, 255, 255, 0.8);
		border: 1px solid var(--border, #e5e7eb);
		border-radius: 12px;
		font-size: 15px;
		color: var(--text, #1f2937);
		cursor: pointer;
		transition: all 0.2s ease;
		box-shadow: 0 2px 4px rgba(0,0,0,0.02);
		text-align: left;
		backdrop-filter: blur(10px);
	}

	.select-trigger:hover {
		border-color: #cbd5e1;
		box-shadow: 0 4px 6px rgba(0,0,0,0.04);
	}

	.select-trigger.open {
		border-color: var(--primary, #3b82f6);
		box-shadow: 0 0 0 4px rgba(59, 130, 246, 0.1);
	}

	.selected-text {
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.selected-text.placeholder {
		color: #94a3b8;
	}

	.chevron {
		display: flex;
		align-items: center;
		color: #64748b;
		transition: transform 0.2s ease;
	}

	.select-trigger.open .chevron {
		transform: rotate(180deg);
	}

	.options-container {
		position: absolute;
		top: calc(100% + 8px);
		left: 0;
		width: 100%;
		background: rgba(255, 255, 255, 0.95);
		border: 1px solid var(--border, #e5e7eb);
		border-radius: 12px;
		box-shadow: 0 10px 25px rgba(0, 0, 0, 0.1);
		z-index: 50;
		max-height: 250px;
		overflow-y: auto;
		backdrop-filter: blur(16px);
		padding: 6px;
		animation: slideDown 0.2s cubic-bezier(0.16, 1, 0.3, 1);
	}

	.option {
		width: 100%;
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 10px 12px;
		background: transparent;
		border: none;
		border-radius: 8px;
		font-size: 15px;
		color: var(--text, #1f2937);
		cursor: pointer;
		text-align: left;
		transition: background 0.15s ease, color 0.15s ease;
	}

	.option:hover {
		background: #f1f5f9;
	}

	.option.selected {
		background: #eff6ff;
		color: var(--primary-dark, #1d4ed8);
		font-weight: 600;
	}

	.check {
		font-weight: bold;
		font-size: 14px;
	}

	@keyframes slideDown {
		from {
			opacity: 0;
			transform: translateY(-8px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}
</style>
