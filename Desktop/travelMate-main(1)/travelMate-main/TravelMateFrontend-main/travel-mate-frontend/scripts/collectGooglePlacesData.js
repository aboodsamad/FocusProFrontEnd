// Standalone script to collect Lebanon places from Google Places and save to CSV
// Run with: node scripts/collectGooglePlacesData.js

import { fetchAllLebanonPlaces } from '../src/services/googlePlacesService.js';
import fs from 'fs';
import path from 'path';

// Convert array of objects to CSV string
function convertToCSV(data) {
  if (data.length === 0) return '';
  
  const headers = Object.keys(data[0]);
  const csvRows = [];
  
  // Add header row
  csvRows.push(headers.join(','));
  
  // Add data rows
  for (const row of data) {
    const values = headers.map(header => {
      const value = row[header];
      // Escape commas and quotes
      if (typeof value === 'string' && (value.includes(',') || value.includes('"'))) {
        return `"${value.replace(/"/g, '""')}"`;
      }
      return value;
    });
    csvRows.push(values.join(','));
  }
  
  return csvRows.join('\n');
}

async function main() {
  console.log('🚀 Starting Lebanon places collection from Google Places API...\n');
  console.log('⚠️  Note: This will use your Google Places API quota.');
  console.log('📊 Estimated API calls: ~200-300 requests');
  console.log('💰 Estimated cost: $0-5 (within free tier if under 10,000 monthly calls)\n');
  console.log('⏱️  This will take approximately 5-10 minutes.\n');
  
  try {
    // Collect all places
    const places = await fetchAllLebanonPlaces((progress) => {
      console.log(`📍 ${progress}`);
    });
    
    console.log(`\n✅ Successfully collected ${places.length} places!\n`);
    
    // Convert to CSV
    console.log('📄 Converting to CSV format...');
    const csv = convertToCSV(places);
    
    // Save to public folder
    const outputPath = path.join(process.cwd(), 'public', 'lebanon_places_google.csv');
    fs.writeFileSync(outputPath, csv, 'utf8');
    
    console.log(`✅ Saved to: ${outputPath}`);
    console.log(`\n📊 Summary:`);
    console.log(`   Total places: ${places.length}`);
    
    // Show breakdown by category
    const byCategory = {};
    places.forEach(place => {
      byCategory[place.Category] = (byCategory[place.Category] || 0) + 1;
    });
    
    console.log(`\n   By Category:`);
    Object.entries(byCategory).forEach(([category, count]) => {
      console.log(`   - ${category}: ${count}`);
    });
    
    // Show breakdown by city
    const byCity = {};
    places.forEach(place => {
      byCity[place.Country] = (byCity[place.Country] || 0) + 1;
    });
    
    console.log(`\n   By City:`);
    Object.entries(byCity).forEach(([city, count]) => {
      console.log(`   - ${city}: ${count}`);
    });
    
    console.log(`\n🎉 Done! You can now use this CSV file in your app.`);
    console.log(`   To use it, update DataLoader.jsx to load from "lebanon_places_google.csv"\n`);
    
  } catch (error) {
    console.error(`\n❌ Error: ${error.message}`);
    console.error(`\nCommon issues:`);
    console.error(`1. API key not valid - check your key in src/services/googlePlacesService.js`);
    console.error(`2. Billing not enabled - go to https://console.cloud.google.com/billing`);
    console.error(`3. Places API not enabled - go to https://console.cloud.google.com/apis/library/places-backend.googleapis.com`);
    console.error(`4. Quota exceeded - wait 24 hours or increase quota in Google Cloud Console`);
    process.exit(1);
  }
}

main();
