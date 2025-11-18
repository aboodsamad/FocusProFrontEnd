# 🚀 Quick Start Guide - Yelp API Integration

## What Changed?

Your app now gets real Lebanon tourism data from **Yelp API** instead of a fake CSV file!

## ⚡ Setup (3 Steps)

### Step 1: Add Your Yelp API Key

Open `src/services/yelpService.js` and find this line:

```javascript
const YELP_API_KEY = "YOUR_YELP_API_KEY_HERE";
```

Replace it with your actual API key:

```javascript
const YELP_API_KEY = "your_actual_key_from_yelp_developer_portal";
```

### Step 2: Run the App

```bash
npm install
npm run dev
```

### Step 3: Wait for Data to Load

First time loading takes **5-10 minutes** because it fetches data from Yelp API.

You'll see progress like:
```
⏳ Loading data from Yelp API...
Fetching Restaurants in Beirut...
Fetched 50 places so far...
Fetching Cafes in Tripoli...
...
✅ Successfully loaded 847 places from Yelp!
```

---

## 💡 Two Ways to Use This

### Option A: Live API Calls (Slow but Always Fresh)

The app fetches from Yelp every time you refresh. Takes 5-10 minutes.

**Good for:** Always having the latest data

**Bad for:** Slow, uses your API quota

### Option B: Pre-collect Data Once (Fast!)

Run this command ONCE to collect all data and save to CSV:

```bash
npm run collect-data
```

This creates `public/lebanon_places_yelp.csv`

Then update `Dashboard.jsx` to use the old `DataLoader` instead of `YelpDataLoader`:

```javascript
// Change this:
import YelpDataLoader from "../components/YelpDataLoader.jsx";

// Back to this:
import DataLoader from "../components/DataLoader.jsx";
```

And update `DataLoader.jsx` to load the new CSV:

```javascript
const url = "/lebanon_places_yelp.csv";  // Instead of tourism_dataset.csv
```

**Good for:** Instant loading, saves API quota

**Bad for:** Data gets outdated (but you can re-collect anytime)

---

## 📊 What Data You Get

From Yelp API, you get **real Lebanon places** with:

- ✅ Real place names (not fake IDs like "kuBZRkVsAR")
- ✅ Real ratings from Yelp users
- ✅ Review counts (used as "Visitors")
- ✅ Photos, addresses, phone numbers
- ✅ GPS coordinates (lat/lng)
- ✅ 8 categories: Restaurants, Cafes, Hotels, Beaches, Tours, Landmarks, Museums, Nightlife
- ✅ 9 Lebanese cities: Beirut, Tripoli, Sidon, Tyre, Byblos, Jounieh, Baalbek, Zahle, Batroun

### Data Structure:

| Field | What It Is |
|-------|-----------|
| Location | Place name (e.g., "Tawlet Restaurant") |
| Country | Lebanese city (e.g., "Beirut") |
| Category | Type (Restaurant, Cafe, etc.) |
| Visitors | Number of Yelp reviews |
| Rating | Yelp rating (1-5 scale) |
| Revenue | Price level ($ to $$$$) as number |
| YelpId | Unique Yelp ID |
| Address | Street address |
| Phone | Phone number |
| ImageUrl | Photo URL |
| Latitude/Longitude | GPS coordinates |

---

## 🎯 Your Dashboard Now Shows

- **Filter by Lebanese city** (Beirut, Tripoli, etc.) - instead of "Country"
- **Filter by category** (Restaurants, Cafes, Hotels, etc.)
- **Stats panel** - Average rating, total visitors (reviews), etc.
- **Bar charts** - Compare cities and categories
- **Data table** - Full list of all places

Everything works the same, just with real Lebanon data! 🇱🇧

---

## 🔥 Recommended Workflow

**For Development:**
1. Run `npm run collect-data` ONCE to get all places
2. Use the CSV file (fast loading)
3. Re-collect weekly or monthly to refresh data

**For Production:**
1. Use the CSV file for fast loading
2. Add a "Refresh Data" button that calls Yelp API
3. Cache results in database

---

## ⚠️ API Limits

Yelp free tier gives you:
- 5000 calls per month
- ~100 calls per day

Collecting full Lebanon dataset uses ~150-200 calls (one time).

That's why **Option B (pre-collect)** is better - collect once, use CSV forever!

---

## 🐛 Problems?

### "API Error: Check your API key"
- You didn't add your key or it's wrong
- Go to Step 1 above

### App loads but no data
- Check browser console (F12) for errors
- Make sure you saved the API key correctly

### Data loads but looks weird
- Open browser console and check for errors
- Check if Yelp returned empty results for some cities

---

## 📧 Need Help?

Check `YELP_API_SETUP.md` for detailed documentation!
