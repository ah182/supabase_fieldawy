/**
 * Migration Script: Cloudinary to Supabase Storage
 * Target: distributor_stories table (image_url field)
 * Bucket: stories
 */

require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');
const https = require('https');
const http = require('http');

// Configuration
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;
const STORAGE_BUCKET = 'stories';
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
    process.exit(1);
}

// Initialize Supabase client with service role key
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// Statistics
let stats = {
    total: 0,
    migrated: 0,
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
    const match = url.match(/\.(jpg|jpeg|png|gif|webp)/i);
    return match ? match[0].toLowerCase() : '.jpg';
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
 * Upload image to Supabase Storage
 */
async function uploadToSupabase(imageBuffer, filename, mimeType) {
    const { data, error } = await supabase.storage
        .from(STORAGE_BUCKET)
        .upload(filename, imageBuffer, {
            contentType: mimeType,
            upsert: true
        });

    if (error) {
        throw error;
    }

    const { data: publicUrlData } = supabase.storage
        .from(STORAGE_BUCKET)
        .getPublicUrl(filename);

    return publicUrlData.publicUrl;
}

/**
 * Update database record with new URL
 */
async function updateDatabase(id, newUrl) {
    const { error } = await supabase
        .from('distributor_stories')
        .update({ image_url: newUrl })
        .eq('id', id);

    if (error) {
        throw error;
    }
}

/**
 * Migrate a single story image
 */
async function migrateStory(record) {
    const { id, image_url, distributor_id } = record;

    console.log(`\n📖 Processing Story ID: ${id}`);
    console.log(`   Distributor: ${distributor_id}`);
    console.log(`   Old URL: ${image_url?.substring(0, 60)}...`);

    if (!image_url) {
        console.log('   ⏭️ Skipped: No image URL');
        stats.skipped++;
        return;
    }

    if (isSupabaseUrl(image_url)) {
        console.log('   ✅ Already migrated to Supabase');
        stats.alreadyMigrated++;
        return;
    }

    if (!isCloudinaryUrl(image_url)) {
        console.log('   ⏭️ Skipped: Not a Cloudinary URL');
        stats.skipped++;
        return;
    }

    if (DRY_RUN) {
        console.log('   🔍 [DRY RUN] Would migrate this image');
        stats.migrated++;
        return;
    }

    try {
        console.log('   📥 Downloading from Cloudinary...');
        const imageBuffer = await downloadImage(image_url);

        const extension = getExtension(image_url);
        const timestamp = Date.now();
        const newFilename = `distributor_stories/${distributor_id}_${timestamp}${extension}`;

        const mimeTypes = {
            '.jpg': 'image/jpeg',
            '.jpeg': 'image/jpeg',
            '.png': 'image/png',
            '.gif': 'image/gif',
            '.webp': 'image/webp'
        };
        const mimeType = mimeTypes[extension] || 'image/jpeg';

        console.log(`   📤 Uploading to Supabase (${STORAGE_BUCKET})...`);
        const newUrl = await uploadToSupabase(imageBuffer, newFilename, mimeType);

        console.log('   💾 Updating database...');
        await updateDatabase(id, newUrl);

        console.log(`   ✅ Migrated successfully!`);
        console.log(`   New URL: ${newUrl.substring(0, 60)}...`);
        stats.migrated++;

    } catch (error) {
        console.log(`   ❌ Failed: ${error.message}`);
        stats.failed++;
    }
}

/**
 * Main migration function
 */
async function migrate() {
    console.log('═══════════════════════════════════════════════════════════');
    console.log('🚀 Starting Migration: Story Images → Supabase Storage');
    console.log('═══════════════════════════════════════════════════════════');
    console.log(`📁 Target bucket: ${STORAGE_BUCKET}`);
    console.log(`🧪 Test mode: ${TEST_MODE ? 'YES (first 5 only)' : 'NO'}`);
    console.log(`🔍 Dry run: ${DRY_RUN ? 'YES (no actual changes)' : 'NO'}`);
    console.log('═══════════════════════════════════════════════════════════\n');

    console.log('📊 Fetching stories from distributor_stories...');

    let query = supabase
        .from('distributor_stories')
        .select('id, image_url, distributor_id')
        .not('image_url', 'is', null);

    if (TEST_MODE) {
        query = query.limit(5);
    }

    const { data: records, error } = await query;

    if (error) {
        console.error('❌ Error fetching records:', error.message);
        process.exit(1);
    }

    stats.total = records.length;
    console.log(`📖 Found ${stats.total} stories with images\n`);

    for (const record of records) {
        await migrateStory(record);
        await new Promise(resolve => setTimeout(resolve, 150));
    }

    console.log('\n═══════════════════════════════════════════════════════════');
    console.log('📊 Migration Summary');
    console.log('═══════════════════════════════════════════════════════════');
    console.log(`   Total stories:     ${stats.total}`);
    console.log(`   ✅ Migrated:       ${stats.migrated}`);
    console.log(`   ✅ Already done:   ${stats.alreadyMigrated}`);
    console.log(`   ⏭️ Skipped:        ${stats.skipped}`);
    console.log(`   ❌ Failed:         ${stats.failed}`);
    console.log('═══════════════════════════════════════════════════════════\n');

    if (stats.failed > 0) {
        console.log('⚠️ Some images failed to migrate. Check the logs above.');
    } else {
        console.log('✅ Migration completed successfully!');
    }
}

migrate().catch(console.error);
