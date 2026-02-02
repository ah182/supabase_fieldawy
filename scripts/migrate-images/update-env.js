const fs = require('fs');
const path = require('path');

const envPath = path.resolve('.env');

const content = `# Supabase credentials
SUPABASE_URL=https://rkukzuwerbvmueuxadul.supabase.co
SUPABASE_SERVICE_KEY=eyJhHbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJrdWt6dXdlcmJ2bXVldXhhZHVsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTczODAzMjcwMiwiZXhwIjoyMDUzNjA4NzAyfQ.2T8gP-5vF4Dq7qY6y2K8f8b8u5z5w5v5x5y5z5A5Gk

# Bucket name
STORAGE_BUCKET=ocr

# Cloudinary Credentials (Updated from chat)
CLOUDINARY_CLOUD_NAME=ddoxy8nbz
CLOUDINARY_API_KEY=456911195232731
CLOUDINARY_API_SECRET=loG9aOW0bBZ1nODldzuoDMZVOaA

# Migration options
TEST_MODE=false
DRY_RUN=false
`;

try {
    fs.writeFileSync(envPath, content);
    console.log('✅ Updated .env with provided credentials.');
} catch (e) {
    console.error('❌ Failed to update .env:', e.message);
}
