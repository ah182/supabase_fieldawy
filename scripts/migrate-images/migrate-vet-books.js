/**
 * Migration Script: Cloudinary to Supabase Storage
 * Target: vet_books table (image_url field)
 * Bucket: ocr
 * Folder: books
 */

require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');
const cloudinary = require('cloudinary').v2;
const https = require('https');
const http = require('http');
const path = require('path');

// Debuging .env loading
console.log(`📂 Current directory: ${process.cwd()}`);
const envPath = path.resolve(process.cwd(), '.env');
console.log(`📄 Looking for .env at: ${envPath}`);

const dotenvResult = require('dotenv').config();
if (dotenvResult.error) {
    console.log(`❌ Error loading .env: ${dotenvResult.error.message}`);
} else {
    console.log('✅ .env loaded via dotenv');
    const keys = Object.keys(dotenvResult.parsed || {});
    console.log(`🔑 Loaded keys from .env: ${keys.join(', ')}`);

    // Manual check
    const fs = require('fs');
    try {
        const envContent = fs.readFileSync(envPath, 'utf8');
        console.log('📄 Raw .env check:');
        if (envContent.includes('CLOUDINARY_CLOUD_NAME')) {
            console.log('   ✅ Found CLOUDINARY_CLOUD_NAME in file content');
            // Check for potential newline issue
            const lines = envContent.split('\n');
            const cloudLine = lines.find(l => l.includes('CLOUDINARY_CLOUD_NAME'));
            console.log(`   📝 Cloud name line: ${cloudLine.replace(/=.+/, '=******')}`);
        } else {
            console.log('   ❌ CLOUDINARY_CLOUD_NAME NOT found in file content');
        }
    } catch (e) {
        console.log(`   ❌ Could not read .env file raw: ${e.message}`);
    }
}

// Configuration
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;
const STORAGE_BUCKET = 'ocr';
const FOLDER_NAME = 'books';
const TEST_MODE = process.argv.includes('--test') || process.env.TEST_MODE === 'true';
const DRY_RUN = process.argv.includes('--dry-run') || process.env.DRY_RUN === 'true';

// Cloudinary Configuration
if (process.env.CLOUDINARY_CLOUD_NAME) {
    cloudinary.config({
        cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
        api_key: process.env.CLOUDINARY_API_KEY,
        api_secret: process.env.CLOUDINARY_API_SECRET,
        secure: true
    });
    console.log(`✅ Cloudinary configured for cloud_name: ${process.env.CLOUDINARY_CLOUD_NAME}`);
} else {
    console.log('⚠️ Cloudinary env vars missing, some private images might fail');
}

// Validate configuration
console.log('🔧 Loaded Configuration:');
console.log('   SUPABASE_URL:', SUPABASE_URL ? SUPABASE_URL.substring(0, 35) + '...' : '❌ NOT SET');
console.log('   SUPABASE_SERVICE_KEY:', SUPABASE_SERVICE_KEY ? '✅ SET (hidden)' : '❌ NOT SET');
console.log('   STORAGE_BUCKET:', STORAGE_BUCKET);
console.log('   FOLDER_NAME:', FOLDER_NAME);
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
 * Extract public_id from Cloudinary URL
 */
function extractPublicId(url) {
    try {
        const parts = url.split('/upload/');
        if (parts.length < 2) return null;

        let path = parts[1];
        // Remove version if present (v12345678/)
        if (path.startsWith('v') && path.includes('/')) {
            const vIndex = path.indexOf('/');
            const vPart = path.substring(0, vIndex);
            if (/^v\d+$/.test(vPart)) {
                path = path.substring(vIndex + 1);
            }
        }

        // Remove extension
        const dotIndex = path.lastIndexOf('.');
        if (dotIndex !== -1) {
            path = path.substring(0, dotIndex);
        }

        return path;
    } catch (e) {
        return null;
    }
}

/**
 * Generate authenticated URL for Cloudinary image
 */
function getAuthenticatedUrl(originalUrl) {
    const publicId = extractPublicId(originalUrl);
    if (!publicId) return originalUrl;

    return cloudinary.url(publicId, {
        sign_url: true,
        type: 'authenticated',
        secure: true
    });
}

/**
 * Download image from URL
 */
async function downloadImage(url) {
    return new Promise((resolve, reject) => {
        const protocol = url.startsWith('https') ? https : http;

        const options = {
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
            }
        };

        const request = protocol.get(url, options, (response) => {
            if (response.statusCode === 301 || response.statusCode === 302) {
                downloadImage(response.headers.location).then(resolve).catch(reject);
                return;
            }

            if (response.statusCode !== 200) {
                reject(new Error(`Failed to download: ${response.statusCode} - URL: ${url}`));
                return;
            }

            const chunks = [];
            response.on('data', (chunk) => chunks.push(chunk));
            response.on('end', () => resolve(Buffer.concat(chunks)));
            response.on('error', reject);
        });

        request.on('error', reject);
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
        .from('vet_books')
        .update({ image_url: newUrl })
        .eq('id', id);

    if (error) {
        throw error;
    }
}

/**
 * Migrate a single book image
 */
async function migrateBook(record) {
    const { id, image_url, name } = record;

    console.log(`\n📚 Processing Book: ${name || id}`);
    console.log(`   ID: ${id}`);
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
        // stats.skipped++;
        // return;
    }

    if (DRY_RUN) {
        console.log('   🔍 [DRY RUN] Would migrate this image');
        stats.migrated++;
        return;
    }

    try {
        let imageBuffer;
        try {
            console.log('   📥 Downloading image...');
            imageBuffer = await downloadImage(image_url);
        } catch (e) {
            if (e.message.includes('401') || e.message.includes('403') || e.message.includes('404')) {
                console.log(`   🔒 Access failed (${e.message}), trying signed URL...`);
                const signedUrl = getAuthenticatedUrl(image_url);
                try {
                    imageBuffer = await downloadImage(signedUrl);
                    console.log('   ✅ Downloaded via signed URL');
                } catch (e2) {
                    // Try one more thing: maybe type is 'upload' but just needs signing?
                    const publicId = extractPublicId(image_url);
                    const signedUploadUrl = cloudinary.url(publicId, {
                        sign_url: true,
                        type: 'upload',
                        secure: true
                    });
                    console.log(`   🔒 Trying standard signed URL (upload type)...`);
                    imageBuffer = await downloadImage(signedUploadUrl);
                    console.log('   ✅ Downloaded via standard signed URL');
                }
            } else {
                throw e;
            }
        }

        const extension = getExtension(image_url);
        const timestamp = Date.now();
        const newFilename = `${FOLDER_NAME}/${id}_${timestamp}${extension}`;

        const mimeTypes = {
            '.jpg': 'image/jpeg',
            '.jpeg': 'image/jpeg',
            '.png': 'image/png',
            '.gif': 'image/gif',
            '.webp': 'image/webp'
        };
        const mimeType = mimeTypes[extension] || 'image/jpeg';

        console.log(`   📤 Uploading to Supabase (${STORAGE_BUCKET}/${FOLDER_NAME})...`);
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
    console.log('🚀 Starting Migration: Vet Books Images → Supabase Storage');
    console.log('═══════════════════════════════════════════════════════════');
    console.log(`📁 Target bucket: ${STORAGE_BUCKET}`);
    console.log(`📂 Target folder: ${FOLDER_NAME}`);
    console.log(`🧪 Test mode: ${TEST_MODE ? 'YES (first 5 only)' : 'NO'}`);
    console.log(`🔍 Dry run: ${DRY_RUN ? 'YES (no actual changes)' : 'NO'}`);

    if (process.env.CLOUDINARY_CLOUD_NAME) {
        console.log(`☁️ Cloudinary: ${process.env.CLOUDINARY_CLOUD_NAME}`);
    }

    console.log('═══════════════════════════════════════════════════════════\n');

    console.log('📊 Fetching books from vet_books...');

    let query = supabase
        .from('vet_books')
        .select('id, image_url, name')
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
    console.log(`📚 Found ${stats.total} books with images\n`);

    for (const record of records) {
        await migrateBook(record);
        await new Promise(resolve => setTimeout(resolve, 150));
    }

    console.log('\n═══════════════════════════════════════════════════════════');
    console.log('📊 Migration Summary');
    console.log('═══════════════════════════════════════════════════════════');
    console.log(`   Total books:       ${stats.total}`);
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
