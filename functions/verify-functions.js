/**
 * Verification Script for Slice 0 Functions
 * Checks that all required functions are exported correctly
 */

const fs = require('fs');
const path = require('path');

console.log('🔍 Verifying Slice 0 Functions...\n');

// Check if compiled output exists
const libPath = path.join(__dirname, 'lib');
const indexJsPath = path.join(libPath, 'index.js');

if (!fs.existsSync(indexJsPath)) {
  console.error('❌ ERROR: Compiled functions not found. Run "npm run build" first.');
  process.exit(1);
}

// Read compiled index.js
const indexJs = fs.readFileSync(indexJsPath, 'utf8');

// Check for required exports
const requiredExports = ['orgCreate', 'orgJoin', 'memberGetMyMembership'];
const missingExports = [];

requiredExports.forEach(exportName => {
  if (indexJs.includes(`exports.${exportName}`) || indexJs.includes(`export { ${exportName}`)) {
    console.log(`✅ ${exportName} is exported`);
  } else {
    console.log(`❌ ${exportName} is MISSING`);
    missingExports.push(exportName);
  }
});

// Check source files exist
console.log('\n📁 Checking source files...');
const sourceFiles = [
  'src/functions/org.ts',
  'src/functions/member.ts',
  'src/utils/response.ts',
  'src/utils/entitlements.ts',
  'src/utils/audit.ts',
  'src/constants/entitlements.ts',
  'src/constants/permissions.ts',
  'src/constants/errors.ts',
];

sourceFiles.forEach(file => {
  const filePath = path.join(__dirname, file);
  if (fs.existsSync(filePath)) {
    console.log(`✅ ${file} exists`);
  } else {
    console.log(`❌ ${file} MISSING`);
  }
});

// Summary
console.log('\n📊 Summary:');
if (missingExports.length === 0) {
  console.log('✅ All required functions are exported correctly!');
  console.log('\n🚀 Next steps to test deployed functions:');
  console.log('1. Go to Firebase Console → Functions');
  console.log('2. Click on orgCreate → Test tab');
  console.log('3. Enter test payload: { "name": "Test Org", "description": "Test" }');
  console.log('4. Click "Test the function"');
  console.log('5. Verify response: { "success": true, "data": {...} }');
  console.log('\n6. Check Firestore for created documents:');
  console.log('   - organizations/{orgId}');
  console.log('   - organizations/{orgId}/members/{uid}');
  console.log('   - organizations/{orgId}/audit_events/{eventId}');
} else {
  console.log(`❌ Missing exports: ${missingExports.join(', ')}`);
  process.exit(1);
}
