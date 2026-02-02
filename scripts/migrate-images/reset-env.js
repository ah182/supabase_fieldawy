const fs = require('fs');
const path = require('path');

const scriptEnvPath = path.resolve('.env');

console.log(`Writing correct template to: ${scriptEnvPath}`);

try {
    let scriptContent = '';
    if (fs.existsSync(scriptEnvPath)) {
        scriptContent = fs.readFileSync(scriptEnvPath, 'utf8');
    }

    // Remove existing Cloudinary keys to avoid confusion
    const lines = scriptContent.split(/\r?\n/);
    const cleanLines = lines.filter(line => !line.trim().startsWith('CLOUDINARY_'));

    let newContent = cleanLines.join('\n').trim();
    if (newContent) newContent += '\n\n';

    // Add the template for djynrtwoq
    newContent += '# Cloudinary Credentials for djynrtwoq (Required for private images)\n';
    newContent += 'CLOUDINARY_CLOUD_NAME=djynrtwoq\n';
    newContent += 'CLOUDINARY_API_KEY=YOUR_API_KEY_HERE\n';
    newContent += 'CLOUDINARY_API_SECRET=YOUR_API_SECRET_HERE\n';

    fs.writeFileSync(scriptEnvPath, newContent);
    console.log('✅ Updated .env with placeholder credentials for djynrtwoq.');
    console.log('⚠️ PLEASE EDIT .env NOW and replace YOUR_API_KEY_HERE and YOUR_API_SECRET_HERE with real values.');

} catch (e) {
    console.log(`❌ Error: ${e.message}`);
}
