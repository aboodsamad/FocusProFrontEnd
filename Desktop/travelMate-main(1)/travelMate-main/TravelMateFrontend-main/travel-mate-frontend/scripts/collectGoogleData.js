import { fetchAllLebanonPlaces } from '../src/services/yelpService.js';
import fs from 'fs';

async function main() {
  console.log('🚀 Collecting Lebanon places from Google...');
  console.log('This will take 10-15 minutes.\n');
  
  const places = await fetchAllLebanonPlaces((progress) => {
    console.log(`📍 ${progress}`);
  });
  
  console.log(`\n✅ Collected ${places.length} places!`);
  
  // Save as JSON
  fs.writeFileSync(
    './public/lebanon_google_places.json',
    JSON.stringify(places, null, 2)
  );
  
  // Save as CSV
  const csv = convertToCSV(places);
  fs.writeFileSync('./public/lebanon_google_places.csv', csv);
  
  console.log('\n💾 Saved to:');
  console.log('   - public/lebanon_google_places.json');
  console.log('   - public/lebanon_google_places.csv');
}

function convertToCSV(data) {
  const headers = Object.keys(data[0]);
  const rows = data.map(row => 
    headers.map(h => {
      const val = row[h];
      return typeof val === 'string' && val.includes(',') 
        ? `"${val}"` 
        : val;
    }).join(',')
  );
  return [headers.join(','), ...rows].join('\n');
}

main();