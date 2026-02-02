/**
 * Migration Script: Cloudinary to Supabase Storage
 * Target: users table (photo_url and document_url fields)
 * Bucket: docs&profiles
 */

require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');
const https = require('https');
const http = require('http');

// Configuration
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;
const STORAGE_BUCKET = 'docs&profiles';
const TEST_MODE = process.argv.includes('--test') || process.env.TEST_MODE === 'true';
const DRY_RUN = process.argv.includes('--dry-run') || process.env.DRY_RUN === 'true';

// Validate configuration
console.log('🔧 Loaded Configuration:');
console.log('   SUPABASE_URL:', SUPABASE_URL ? SUPABASE_URL.substring(0, 35) + '...' : '❌ NOT SET');
console.log('   SUPABASE_SERVICE_KEY:', SUPABASE_SERVICE_KEY ? '✅ SET (hidden)' : '❌ NOT SET');
console.log('   STORAGE_BUCKET:', STORAGE_BUCKET);
console.log('');

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
    console.error('❌ Missing SUPABASE_URL or SUPABASE_SERVICE_KEY in .env file');
    console.error('');
    console.error('📝 Make sure your .env file contains:');
    console.error('   SUPABASE_URL=https://xxxxx.supabase.co');
    console.error('   SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6...');
    process.exit(1);
}

// Initialize Supabase client with service role key
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// Statistics
let stats = {
    total: 0,
    photoMigrated: 0,
    documentMigrated: 0,
    skipped: 0,
    failed: 0,
    alreadyMigrated: 0
};

/**
 * Download image from URL
 */
async function downloadImage(url) {
    return new Promise((resolve, reject) => {
        const protocol = url.startsWith('https') ? https : http;

        protocol.get(url, (response) => {
            // Handle redirects
            if (response.statusCode === 301 || response.statusCode === 302) {
                downloadImage(response.headers.location).then(resolve).catch(reject);
                return;
            }

            if (response.statusCode !== 200) {
                reject(new Error(`Failed to download: ${response.statusCode}`));
                return;
            }

            const chunks = [];
            response.on('data', (chunk) => chunks.push(chunk));
            response.on('end', () => resolve(Buffer.concat(chunks)));
            response.on('error', reject);
        }).on('error', reject);
    });
}

/**
 * Get file extension from URL
 */
function getExtension(url) {
    const match = url.match(/\.(jpg|jpeg|png|gif|webp|avif|pdf)/i);
    return match ? match[0].toLowerCase() : '.jpg';
}

/**
 * Extract filename from URL
 */
function extractFilename(url) {
    try {
        const parts = url.split('/');
        const filename = parts[parts.length - 1];
        return filename.split('.')[0]; // Remove extension
    } catch (e) {
        return `file_${Date.now()}`;
    }
}

/**
 * Check if URL is from Cloudinary
 */
function isCloudinaryUrl(url) {
    return url && url.includes('cloudinary.com');
}

/**
 * Check if URL is already from Supabase
 */
function isSupabaseUrl(url) {
    return url && url.includes('supabase');
}

/**
 * Check if URL needs migration (not empty, not Supabase)
 */
function needsMigration(url) {
    if (!url || url.trim() === '') return false;
    if (isSupabaseUrl(url)) return false;
    return true;
}

/**
 * Upload file to Supabase Storage
 */
async function uploadToSupabase(fileBuffer, filename, mimeType) {
    const { data, error } = await supabase.storage
        .from(STORAGE_BUCKET)
        .upload(filename, fileBuffer, {
            contentType: mimeType,
            upsert: true
        });

    if (error) {
        throw error;
    }

    // Get public URL
    const { data: publicUrlData } = supabase.storage
        .from(STORAGE_BUCKET)
        .getPublicUrl(filename);

    return publicUrlData.publicUrl;
}

/**
 * Update database record with new URLs
 */
async function updateDatabase(userId, updates) {
    const { error } = await supabase
        .from('users')
        .update(updates)
        .eq('id', userId);

    if (error) {
        throw error;
    }
}

/**
 * Migrate a single file (photo or document)
 */
async function migrateFile(url, userId, fileType) {
    console.log(`   📥 Downloading ${fileType}...`);
    const fileBuffer = await downloadImage(url);

    // Generate new filename with folder structure
    const originalFilename = extractFilename(url);
    const extension = getExtension(url);
    const folder = fileType === 'photo' ? 'photos' : 'documents';
    const newFilename = `${folder}/${userId}_${originalFilename}${extension}`;

    // Determine MIME type
    const mimeTypes = {
        '.jpg': 'image/jpeg',
        '.jpeg': 'image/jpeg',
        '.png': 'image/png',
        '.gif': 'image/gif',
        '.webp': 'image/webp',
        '.avif': 'image/avif',
        '.pdf': 'application/pdf'
    };
    const mimeType = mimeTypes[extension] || 'image/jpeg';

    // Upload to Supabase
    console.log(`   📤 Uploading ${fileType} to Supabase (${STORAGE_BUCKET}/${folder})...`);
    const newUrl = await uploadToSupabase(fileBuffer, newFilename, mimeType);

    return newUrl;
}

/**
 * Migrate a single user's files
 */
async function migrateUser(user) {
    const { id, photo_url, document_url, display_name } = user;

    console.log(`\n👤 Processing User: ${display_name || id}`);
    console.log(`   ID: ${id}`);

    const updates = {};
    let hasUpdates = false;

    // Process photo_url
    if (photo_url) {
        console.log(`   📷 Photo URL: ${photo_url?.substring(0, 60)}...`);

        if (isSupabaseUrl(photo_url)) {
            console.log('   ✅ Photo already migrated to Supabase');
            stats.alreadyMigrated++;
        } else if (needsMigration(photo_url)) {
            if (DRY_RUN) {
                console.log('   🔍 [DRY RUN] Would migrate photo');
                stats.photoMigrated++;
            } else {
                try {
                    const newPhotoUrl = await migrateFile(photo_url, id, 'photo');
                    updates.photo_url = newPhotoUrl;
                    hasUpdates = true;
                    console.log(`   ✅ Photo migrated!`);
                    console.log(`   New URL: ${newPhotoUrl.substring(0, 60)}...`);
                    stats.photoMigrated++;
                } catch (error) {
                    console.log(`   ❌ Photo migration failed: ${error.message}`);
                    stats.failed++;
                }
            }
        } else {
            console.log('   ⏭️ Photo skipped: Empty or invalid URL');
            stats.skipped++;
        }
    }

    // Process document_url
    if (document_url) {
        console.log(`   📄 Document URL: ${document_url?.substring(0, 60)}...`);

        if (isSupabaseUrl(document_url)) {
            console.log('   ✅ Document already migrated to Supabase');
            stats.alreadyMigrated++;
        } else if (needsMigration(document_url)) {
            if (DRY_RUN) {
                console.log('   🔍 [DRY RUN] Would migrate document');
                stats.documentMigrated++;
            } else {
                try {
                    const newDocUrl = await migrateFile(document_url, id, 'document');
                    updates.document_url = newDocUrl;
                    hasUpdates = true;
                    console.log(`   ✅ Document migrated!`);
                    console.log(`   New URL: ${newDocUrl.substring(0, 60)}...`);
                    stats.documentMigrated++;
                } catch (error) {
                    console.log(`   ❌ Document migration failed: ${error.message}`);
                    stats.failed++;
                }
            }
        } else {
            console.log('   ⏭️ Document skipped: Empty or invalid URL');
            stats.skipped++;
        }
    }

    // Update database if there are changes
    if (hasUpdates && !DRY_RUN) {
        console.log('   💾 Updating database...');
        try {
            await updateDatabase(id, updates);
            console.log('   ✅ Database updated successfully!');
        } catch (error) {
            console.log(`   ❌ Database update failed: ${error.message}`);
            stats.failed++;
        }
    }
}

/**
 * Main migration function
 */
async function migrate() {
    console.log('═══════════════════════════════════════════════════════════');
    console.log('🚀 Starting Migration: Users Files → Supabase Storage');
    console.log('═══════════════════════════════════════════════════════════');
    console.log(`📁 Target bucket: ${STORAGE_BUCKET}`);
    console.log(`📷 Migrating: photo_url → ${STORAGE_BUCKET}/photos/`);
    console.log(`📄 Migrating: document_url → ${STORAGE_BUCKET}/documents/`);
    console.log(`🧪 Test mode: ${TEST_MODE ? 'YES (first 5 only)' : 'NO'}`);
    console.log(`🔍 Dry run: ${DRY_RUN ? 'YES (no actual changes)' : 'NO'}`);
    console.log('═══════════════════════════════════════════════════════════\n');

    // Fetch users with photo_url or document_url
    console.log('📊 Fetching users with photos or documents...');

    let query = supabase
        .from('users')
        .select('id, display_name, photo_url, document_url')
        .or('photo_url.not.is.null,document_url.not.is.null');

    if (TEST_MODE) {
        query = query.limit(5);
    }

    const { data: users, error } = await query;

    if (error) {
        console.error('❌ Error fetching users:', error.message);
        process.exit(1);
    }

    stats.total = users.length;
    console.log(`👥 Found ${stats.total} users with photos/documents\n`);

    // Migrate each user's files
    for (const user of users) {
        await migrateUser(user);

        // Add a small delay to avoid rate limiting
        await new Promise(resolve => setTimeout(resolve, 200));
    }

    // Print summary
    console.log('\n═══════════════════════════════════════════════════════════');
    console.log('📊 Migration Summary');
    console.log('═══════════════════════════════════════════════════════════');
    console.log(`   Total users:         ${stats.total}`);
    console.log(`   📷 Photos migrated:  ${stats.photoMigrated}`);
    console.log(`   📄 Docs migrated:    ${stats.documentMigrated}`);
    console.log(`   ✅ Already done:     ${stats.alreadyMigrated}`);
    console.log(`   ⏭️ Skipped:          ${stats.skipped}`);
    console.log(`   ❌ Failed:           ${stats.failed}`);
    console.log('═══════════════════════════════════════════════════════════\n');

    if (stats.failed > 0) {
        console.log('⚠️ Some files failed to migrate. Check the logs above.');
    } else {
        console.log('✅ Migration completed successfully!');
    }
}

// Run migration
migrate().catch(console.error);
