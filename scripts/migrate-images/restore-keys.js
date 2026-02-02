const fs = require('fs');
const path = require('path');

const rootEnvPath = path.resolve('..', '..', '.env');
const scriptEnvPath = path.resolve('.env');

console.log(`Reading keys from: ${rootEnvPath}`);
console.log(`Target file: ${scriptEnvPath}`);

try {
    if (fs.existsSync(rootEnvPath)) {
        const rootContent = fs.readFileSync(rootEnvPath, 'utf8');
        const rootLines = rootContent.split(/\r?\n/);

        let supabaseUrl = '';
        let supabaseKey = '';

        // Find correct keys in root
        rootLines.forEach(line => {
            if (line.trim().startsWith('SUPABASE_URL=')) supabaseUrl = line.trim();
            if (line.trim().startsWith('SUPABASE_SERVICE_KEY=')) supabaseKey = line.trim();
            // Also looking for ANON key just in case, but SERVICE_KEY is what we need
        });

        if (!supabaseUrl || !supabaseKey) {
            console.log('❌ Could not find SUPABASE_URL or SUPABASE_SERVICE_KEY in root .env');
            // Try to find them in script env just to see what we have
            if (fs.existsSync(scriptEnvPath)) {
                console.log('Current local content may be corrupted.');
            }
        } else {
            console.log('✅ Found Supabase keys in root .env');

            // Read local .env
            let scriptContent = '';
            if (fs.existsSync(scriptEnvPath)) {
                scriptContent = fs.readFileSync(scriptEnvPath, 'utf8');
            }

            let lines = scriptContent.split(/\r?\n/);

            // Remove existing Supabase lines
            lines = lines.filter(line => !line.trim().startsWith('SUPABASE_URL') && !line.trim().startsWith('SUPABASE_SERVICE_KEY'));

            // Prepend new keys
            let newContent = supabaseUrl + '\n' + supabaseKey + '\n\n' + lines.join('\n').trim();

            fs.writeFileSync(scriptEnvPath, newContent);
            console.log('✅ Restored Supabase keys to local .env');
        }

    } else {
        console.log('❌ Root .env file does NOT exist');
    }
} catch (e) {
    console.log(`❌ Error: ${e.message}`);
}
