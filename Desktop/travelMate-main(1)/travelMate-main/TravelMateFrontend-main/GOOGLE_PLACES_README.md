# Lebanon Tourism App - Google Places API Integration

## ✅ CHANGES MADE

Your app has been successfully converted from Yelp API to Google Places API!

### Files Added:
1. **`src/services/googlePlacesService.js`** - Google Places API service (replaces yelpService.js)
2. **`src/components/GooglePlacesDataLoader.jsx`** - Data loader component for Google Places
3. **`scripts/collectGooglePlacesData.js`** - Script to collect and save Lebanon places data
4. **`test_google_places.html`** - Simple test page to verify API is working

### Your API Key:
```
AIzaSyBfhArL3nc5UxL31qILqOS_1H0JTNiXj_o
```
✅ Already configured in all new files!

---

## 🚀 QUICK START

### Step 1: Test Your API Key

Open `test_google_places.html` in your browser:
```bash
# Just double-click the file or open it in Chrome/Firefox
```

You should see:
- ✅ Map of Beirut loads
- ✅ "Test API Connection" button works
- ✅ Search buttons return results

If you see errors, check:
1. Billing enabled: https://console.cloud.google.com/billing
2. Places API enabled: https://console.cloud.google.com/apis/library/places-backend.googleapis.com

### Step 2: Update Your React App

**Option A: Use the new GooglePlacesDataLoader component**

In your `App.jsx` or wherever you use `YelpDataLoader`:

```jsx
// OLD:
import YelpDataLoader from './components/YelpDataLoader';

// NEW:
import GooglePlacesDataLoader from './components/GooglePlacesDataLoader';

// Then in your JSX:
// OLD:
<YelpDataLoader onData={setData} />

// NEW:
<GooglePlacesDataLoader onData={setData} />
```

**Option B: Collect data once and save as CSV**

```bash
cd travel-mate-frontend
node scripts/collectGooglePlacesData.js
```

This will:
- Fetch all Lebanon places from Google Places API
- Save to `public/lebanon_places_google.csv`
- Take 5-10 minutes
- Use ~200-300 API calls (within free tier)

Then update your DataLoader to use the CSV instead of live API.

---

## 📊 WHAT YOU GET

### Data Structure:
```json
{
  "Location": "Roadster Diner",
  "Country": "Beirut",
  "Category": "Restaurants",
  "Visitors": 1543,          // user_ratings_total
  "Rating": 4.3,             // 1-5 scale
  "Revenue": 5000,           // Based on price_level
  "Accommodation_Available": "No",
  "PlaceId": "ChIJ...",
  "Address": "ABC Mall, Achrafieh",
  "ImageUrl": "https://maps.googleapis.com/...",
  "Latitude": 33.8886,
  "Longitude": 35.4955,
  "PriceLevel": 2,           // 0-4 scale
  "IsOpen": true,
  "Types": "restaurant, food, point_of_interest"
}
```

### Categories Covered:
- ✅ Restaurants
- ✅ Cafes
- ✅ Hotels
- ✅ Beaches
- ✅ Tours
- ✅ Landmarks
- ✅ Museums
- ✅ Nightlife

### Cities Covered:
- Beirut
- Tripoli
- Sidon
- Tyre
- Byblos
- Jounieh
- Baalbek
- Zahle
- Batroun

---

## 💰 PRICING & QUOTAS

### Google Places API Free Tier:
- **10,000 API calls/month FREE**
- After that: ~$5 per 1,000 calls

### Your Project Usage:
- One-time data collection: ~200-300 calls
- Live API usage: depends on app traffic

### Cost Estimate:
- **Capstone project: $0** (well within free tier)
- Production app with 1000 users/day: ~$10-30/month

---

## 🔧 TROUBLESHOOTING

### Error: "REQUEST_DENIED"
**Solution:** Enable the Places API
1. Go to: https://console.cloud.google.com/apis/library/places-backend.googleapis.com
2. Click "Enable"

### Error: "OVER_QUERY_LIMIT"
**Solution:** You've exceeded your quota
1. Wait 24 hours for reset
2. Or collect data once and save as CSV

### Error: "Billing not enabled"
**Solution:** Enable billing
1. Go to: https://console.cloud.google.com/billing
2. Add payment method ($10 prepayment required)
3. You won't be charged if you stay under 10,000 calls/month

### No results or limited results
**Solution:** Normal for some categories
- Google Places API may have less data than expected
- Some categories (like "Beaches") return fewer results
- Increase radius or adjust search parameters

---

## 📝 COMPARISON: Yelp vs Google Places

| Feature | Yelp API | Google Places API |
|---------|----------|-------------------|
| **Free Tier** | ❌ Paid only ($7.99/1k calls) | ✅ 10,000 calls/month |
| **Photos** | ✅ Yes | ✅ Yes |
| **Ratings** | ✅ Yes (1-5) | ✅ Yes (1-5) |
| **Reviews** | ✅ Text reviews | ⚠️ Limited |
| **Lebanon Coverage** | ⚠️ Limited | ✅ Good |
| **Setup** | Credit card | Credit card ($10 prepayment) |

---

## 🎓 FOR YOUR CAPSTONE PROJECT

### What Your Professor Cares About:
1. ✅ App functionality
2. ✅ Code quality
3. ✅ AWS integration (RDS, S3, EC2, etc.)
4. ❌ Data source (doesn't matter!)

### Recommended Approach:
1. Run `collectGooglePlacesData.js` **once**
2. Get your CSV file with ~200-500 Lebanon places
3. Upload to **AWS S3** or store in **AWS RDS**
4. Use that data in your app (no live API calls needed)

This way:
- ✅ No API costs during demo
- ✅ Fast loading (no API delays)
- ✅ Shows AWS skills (S3/RDS)
- ✅ Professional approach

---

## 🆘 NEED HELP?

### Check Your API Status:
https://console.cloud.google.com/apis/dashboard

### View Your Billing:
https://console.cloud.google.com/billing

### Google Places API Docs:
https://developers.google.com/maps/documentation/places/web-service

---

## ✨ NEXT STEPS

1. **Test the API:** Open `test_google_places.html` ✅
2. **Choose your approach:**
   - Live API: Use `GooglePlacesDataLoader.jsx`
   - CSV file: Run `collectGooglePlacesData.js`
3. **Update your app** to use the new components
4. **Deploy to AWS** and impress your professor!

---

## 📞 YOUR API KEY (REMINDER)

```
AIzaSyBfhArL3nc5UxL31qILqOS_1H0JTNiXj_o
```

Keep it safe! Don't commit to public GitHub repos.

---

Good luck with your capstone project! 🚀🇱🇧
