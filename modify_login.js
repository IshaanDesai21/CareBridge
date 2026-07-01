const fs = require('fs');
let content = fs.readFileSync('dashboard/src/routes/login/+page.svelte', 'utf8');

// 1. Add demo login helper function
content = content.replace(
    `	async function handleSubmit(e) {`,
    `	async function demoLogin(demoRole) {
		loading = true;
		error = '';
		try {
			// Fast register/login for demo purposes
			let demoEmail = demoRole + '@demo.com';
			let result;
			try {
				result = await login(demoEmail, 'demo1234');
			} catch (e) {
				result = await register(demoEmail, 'demo1234', 'Demo', demoRole.charAt(0).toUpperCase() + demoRole.slice(1), demoRole);
			}
			auth.login(result.token, result.user);
			addNotification(\`Signed in as Demo \${demoRole}!\`, 'success');
			goto('/dashboard');
		} catch (err) {
			error = err.message;
		} finally {
			loading = false;
		}
	}

	async function handleSubmit(e) {`
);

// 2. Add Demo login buttons in the UI above the tabs
const demoButtonsHtml = `
			<!-- Demo Quick Logins -->
			<div class="demo-logins">
				<p class="demo-label">Quick Testing Login:</p>
				<div class="demo-buttons">
					<button class="btn btn-sm btn-secondary" on:click={() => demoLogin('patient')}>👤 Patient</button>
					<button class="btn btn-sm btn-secondary" on:click={() => demoLogin('caregiver')}>⚕️ Caregiver</button>
					<button class="btn btn-sm btn-secondary" on:click={() => demoLogin('family')}>👪 Family</button>
				</div>
			</div>

			<!-- Tab switcher -->`;

content = content.replace(`			<!-- Tab switcher -->`, demoButtonsHtml);

// 3. Add styles for demo logins
content = content.replace(
    `	.tabs {`,
    `	.demo-logins { margin-bottom: 24px; padding: 16px; background: rgba(59, 130, 246, 0.05); border: 1px dashed var(--primary); border-radius: 12px; }
	.demo-label { font-size: 12px; color: var(--primary); font-weight: 700; text-transform: uppercase; margin-bottom: 12px; text-align: center; }
	.demo-buttons { display: flex; gap: 8px; justify-content: center; flex-wrap: wrap; }
	.tabs {`
);

fs.writeFileSync('dashboard/src/routes/login/+page.svelte', content);
console.log("Updated login page");
