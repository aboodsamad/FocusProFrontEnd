# Lebanon Tourism Dashboard - Yelp API Integration

## ✅ Setup Instructions

### 1. Add Your Yelp API Key

Open `src/services/yelpService.js` and replace the API key:

```javascript
const YELP_API_KEY = "YOUR_ACTUAL_YELP_API_KEY_HERE";
```

### 2. Install Dependencies (if needed)

```bash
npm install
```

### 3. Run the App

```bash
npm run dev
```

### 4. First Load

The first time you load the dashboard, it will:
- Test your Yelp API connection
- Fetch places from 9 Lebanese cities
- Collect 8 categories (Restaurants, Cafes, Hotels, Beaches, Tours, Landmarks, Museums, Nightlife)
- **This takes 5-10 minutes** (to respect API rate limits)
- Shows progress as it loads

### 5. Data Structure

The app transforms Yelp data to match your existing dashboard:

| Field | Yelp Source | Description |
|-------|-------------|-------------|
| Location | business.name | Place name |
| Country | city name | Lebanese city (Beirut, Tripoli, etc.) |
| Category | category | Type (Restaurant, Cafe, Hotel, etc.) |
| Visitors | review_count | Number of reviews (proxy for popularity) |
| Rating | rating | Yelp rating (1-5 scale) |
| Revenue | price level | $ to $$$$ converted to numbers |
| Accommodation_Available | category | "Yes" for hotels, "No" otherwise |

**Extra fields added:**
- YelpId
- Address  
- Phone
- ImageUrl
- Latitude/Longitude
- Price
- IsClosed

## 📊 How It Works

### Data Collection Process:

```
For each city (Beirut, Tripoli, Sidon, etc.):
  For each category (Restaurants, Cafes, etc.):
    Fetch up to 200 places
    Wait 1 second (API rate limit)
    Transform data to match dashboard format
    Add to dataset
```

### API Limits:
- **Yelp free tier:** 5000 calls/month
- **Daily limit:** ~100 calls/day
- **Full dataset:** Uses ~150-200 calls total
- **Collection time:** ~5-10 minutes

## 🔧 Customization

### Add More Cities:

Edit `LEBANESE_CITIES` in `src/services/yelpService.js`:

```javascript
const LEBANESE_CITIES = [
  "Beirut, Lebanon",
  "Tripoli, Lebanon",
  "Your City, Lebanon"  // Add here
];
```

### Add More Categories:

Edit `CATEGORIES` in `src/services/yelpService.js`:

```javascript
const CATEGORIES = {
  "Restaurants": "restaurants",
  "Your Category": "category_id"  // Add here
};
```

Full category list: https://docs.developer.yelp.com/docs/resources-categories

### Change Results Per City:

In `fetchAllLebanonPlaces()`, change the loop limit:

```javascript
// Current: up to 200 results per city/category
for (let offset = 0; offset < 200; offset += 50) {

// Change to 100 for faster loading:
for (let offset = 0; offset < 100; offset += 50) {
```

## 🐛 Troubleshooting

### "API Error: 401"
- Your API key is wrong or expired
- Make sure you copied it correctly from Yelp Developer Portal

### "API Error: 429"  
- You hit the rate limit
- Wait an hour and try again
- Or reduce the number of cities/categories

### No results for a city
- Some cities might not have data in Yelp
- Try searching manually on Yelp.com first

### Slow loading
- Normal! It takes 5-10 minutes
- The progress indicator shows current status
- You can reduce cities/categories for faster testing

## 💾 Save Data for Offline Use

Add this function to save collected data:

```javascript
// In Dashboard.jsx after data loads
useEffect(() => {
  if (data.length > 0) {
    // Save to localStorage
    localStorage.setItem('lebanonPlaces', JSON.stringify(data));
    
    // Or download as CSV
    const csv = convertToCSV(data);
    downloadCSV(csv, 'lebanon_places.csv');
  }
}, [data]);
```

Then you can load from localStorage instead of calling Yelp API every time!

## 📝 Notes

- The dashboard filters now work by **City** instead of Country
- All data is from Lebanon
- Filter panel shows Lebanese cities: Beirut, Tripoli, Sidon, etc.
- Charts and stats work exactly the same as before

## 🎯 Next Steps

1. **Save data offline** - Store in database or localStorage after first load
2. **Add caching** - Don't fetch from Yelp every time
3. **Add images** - Display place photos from ImageUrl field
4. **Add map view** - Use Latitude/Longitude for map markers
5. **User ratings** - Let users add their own ratings/comments
