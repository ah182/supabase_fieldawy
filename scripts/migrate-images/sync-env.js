const fs = require('fs');
const path = require('path');

const rootEnvPath = path.resolve('..', '..', '.env');
const scriptEnvPath = path.resolve('.env');

console.log(`Reading from: ${rootEnvPath}`);
console.log(`Writing to: ${scriptEnvPath}`);

try {
    if (fs.existsSync(rootEnvPath)) {
        const rootContent = fs.readFileSync(rootEnvPath, 'utf8');
        // Find lines starting with CLOUDINARY_ (ignoring comments)
        const cloudinaryLines = rootContent.split(/\r?\n/)
            .filter(line => line.trim().startsWith('CLOUDINARY_'));

        if (cloudinaryLines.length > 0) {
            console.log(`Found ${cloudinaryLines.length} Cloudinary keys in root .env`);

            let scriptContent = '';
            if (fs.existsSync(scriptEnvPath)) {
                scriptContent = fs.readFileSync(scriptEnvPath, 'utf8');
            }

            let newContent = scriptContent;
            if (newContent && !newContent.endsWith('\n')) newContent += '\n';

            let addedCount = 0;
            cloudinaryLines.forEach(line => {
                const key = line.split('=')[0].trim();
                if (!scriptContent.includes(key)) {
                    newContent += line.trim() + '\n';
                    console.log(`Appending: ${key}`);
                    addedCount++;
                } else {
                    console.log(`Key ${key} already exists in target (skipping)`);
                }
            });

            if (addedCount > 0) {
                fs.writeFileSync(scriptEnvPath, newContent);
                console.log(`✅ Successfully added ${addedCount} keys to .env!`);
            } else {
                console.log('⚠️ No new keys were added (already exist or none found).');
            }
        } else {
            console.log('❌ No Cloudinary keys found in root .env');
        }
    } else {
        console.log('❌ Root .env file does NOT exist');
    }
} catch (e) {
    console.log(`❌ Error: ${e.message}`);
}
