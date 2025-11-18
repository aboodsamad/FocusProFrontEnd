// Standalone script to collect Lebanon places from Yelp and save to CSV
// Run with: node scripts/collectYelpData.js

import { fetchAllLebanonPlaces } from '../src/services/yelpService.js';
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
  console.log('🚀 Starting Lebanon places collection from Yelp...\n');
  console.log('This will take approximately 5-10 minutes.\n');
  
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
    const outputPath = path.join(process.cwd(), 'public', 'lebanon_places_yelp.csv');
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
    console.log(`   To use it, update DataLoader.jsx to load from "lebanon_places_yelp.csv"\n`);
    
  } catch (error) {
    console.error(`\n❌ Error: ${error.message}`);
    console.error(`\nMake sure:`);
    console.error(`1. You've added your Yelp API key in src/services/yelpService.js`);
    console.error(`2. Your API key is valid and has available quota`);
    process.exit(1);
  }
}

main();
