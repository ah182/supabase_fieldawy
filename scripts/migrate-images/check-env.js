const fs = require('fs');
const path = require('path');

console.log('--- Directory Listing ---');
try {
    fs.readdirSync('.').forEach(file => {
        console.log(file);
    });
} catch (e) {
    console.log('Error listing directory:', e.message);
}

console.log('\n--- .env Content Check ---');
try {
    if (fs.existsSync('.env')) {
        const content = fs.readFileSync('.env', 'utf8');
        console.log('File encoding:', 'utf8'); // Assuming utf8
        const lines = content.split(/\r?\n/);
        lines.forEach((line, index) => {
            const trimmed = line.trim();
            if (!trimmed) return;
            if (trimmed.startsWith('#')) {
                console.log(`Line ${index + 1}: [COMMENT]`);
                return;
            }
            const parts = trimmed.split('=');
            if (parts.length > 1) {
                const key = parts[0].trim();
                const value = parts.slice(1).join('=').trim();
                const maskedValue = value.length > 4 ? value.substring(0, 2) + '*'.repeat(value.length - 4) + value.substring(value.length - 2) : '****';
                console.log(`Line ${index + 1}: ${key}=${maskedValue}`);
            } else {
                console.log(`Line ${index + 1}: [INVALID FORMAT] ${trimmed.substring(0, 10)}...`);
            }
        });
    } else {
        console.log('❌ .env file does NOT exist');
    }
} catch (e) {
    console.log('Error reading .env:', e.message);
}
