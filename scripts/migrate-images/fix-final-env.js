const fs = require('fs');
const path = require('path');

const envPath = path.resolve('.env');

// Recovered keys
const SUPABASE_URL = 'https://rkukzuwerbvmueuxadul.supabase.co';
const SUPABASE_SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJrdWt6dXdlcmJ2bXVldXhhZHVsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1Nzg1NzA4NywiZXhwIjoyMDczNDMzMDg3fQ.NvyFIXcwJdKPZZZ9zJXP-K_3FovI6_8XtEeuip_9IGk';

// User provided Cloudinary keys
const CLOUDINARY_CLOUD_NAME = 'ddoxy8nbz';
const CLOUDINARY_API_KEY = '456911195232731';
const CLOUDINARY_API_SECRET = 'loG9aOW0bBZ1nODldzuoDMZVOaA';

const content = `# Supabase credentials
SUPABASE_URL=${SUPABASE_URL}
SUPABASE_SERVICE_KEY=${SUPABASE_SERVICE_KEY}

# Bucket name
STORAGE_BUCKET=ocr

# Cloudinary Credentials
CLOUDINARY_CLOUD_NAME=${CLOUDINARY_CLOUD_NAME}
CLOUDINARY_API_KEY=${CLOUDINARY_API_KEY}
CLOUDINARY_API_SECRET=${CLOUDINARY_API_SECRET}

# Migration options
TEST_MODE=false
DRY_RUN=false
`;

try {
    fs.writeFileSync(envPath, content);
    console.log('✅ Restored .env with valid Supabase keys and user Cloudinary keys.');
} catch (e) {
    console.error('❌ Failed to restore .env:', e.message);
}
