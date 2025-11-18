// Google Places API Service for Lebanon Places

const GOOGLE_API_KEY = "AIzaSyBfhArL3nc5UxL31qILqOS_1H0JTNiXj_o";
const GOOGLE_PLACES_API_BASE = "https://maps.googleapis.com/maps/api/place";

// Lebanese cities to search with their coordinates
const LEBANESE_CITIES = [
  { name: "Beirut", lat: 33.8886, lng: 35.4955 },
  { name: "Tripoli", lat: 34.4333, lng: 35.8500 },
  { name: "Sidon", lat: 33.5630, lng: 35.3688 },
  { name: "Tyre", lat: 33.2733, lng: 35.2039 },
  { name: "Byblos", lat: 34.1184, lng: 35.6484 },
  { name: "Jounieh", lat: 33.9808, lng: 35.6178 },
  { name: "Baalbek", lat: 34.0059, lng: 36.2081 },
  { name: "Zahle", lat: 33.8462, lng: 35.9015 },
  { name: "Batroun", lat: 34.2550, lng: 35.6586 }
];

// Map categories to Google Places types
const CATEGORY_TO_TYPES = {
  "Restaurants": ["restaurant"],
  "Cafes": ["cafe"],
  "Hotels": ["lodging"],
  "Beaches": ["tourist_attraction"], // Will filter by keyword
  "Tours": ["travel_agency", "tourist_attraction"],
  "Landmarks": ["tourist_attraction", "point_of_interest"],
  "Museums": ["museum"],
  "Nightlife": ["night_club", "bar"]
};

/**
 * Search for places using Google Places Nearby Search
 */
export async function searchPlaces(location, types, radius = 5000, keyword = null, pageToken = null) {
  const url = new URL(`${GOOGLE_PLACES_API_BASE}/nearbysearch/json`);
  
  url.searchParams.append("location", `${location.lat},${location.lng}`);
  url.searchParams.append("radius", radius);
  url.searchParams.append("key", GOOGLE_API_KEY);
  
  if (types && types.length > 0) {
    url.searchParams.append("type", types[0]); // Google accepts one type at a time
  }
  
  if (keyword) {
    url.searchParams.append("keyword", keyword);
  }
  
  if (pageToken) {
    url.searchParams.append("pagetoken", pageToken);
  }

  const response = await fetch(url);

  if (!response.ok) {
    throw new Error(`Google Places API error: ${response.status}`);
  }

  const data = await response.json();
  
  if (data.status === "REQUEST_DENIED") {
    throw new Error(`API Error: ${data.error_message || "Request denied. Check your API key and billing."}`);
  }
  
  if (data.status === "OVER_QUERY_LIMIT") {
    throw new Error("API quota exceeded. Wait a moment and try again.");
  }

  return data;
}

/**
 * Get detailed information about a specific place
 */
export async function getPlaceDetails(placeId) {
  const url = new URL(`${GOOGLE_PLACES_API_BASE}/details/json`);
  url.searchParams.append("place_id", placeId);
  url.searchParams.append("key", GOOGLE_API_KEY);
  url.searchParams.append("fields", "name,formatted_address,formatted_phone_number,rating,user_ratings_total,price_level,opening_hours,website,photos,geometry");

  const response = await fetch(url);

  if (!response.ok) {
    throw new Error(`Google Places API error: ${response.status}`);
  }

  const data = await response.json();
  
  if (data.status !== "OK") {
    throw new Error(`API Error: ${data.status}`);
  }

  return data.result;
}

/**
 * Get photo URL from photo reference
 */
export function getPhotoUrl(photoReference, maxWidth = 400) {
  return `${GOOGLE_PLACES_API_BASE}/photo?maxwidth=${maxWidth}&photo_reference=${photoReference}&key=${GOOGLE_API_KEY}`;
}

/**
 * Fetch all places from Lebanon
 * This will take a while - shows progress via callback
 */
export async function fetchAllLebanonPlaces(onProgress) {
  const allPlaces = [];
  let totalFetched = 0;
  const seenPlaceIds = new Set(); // Avoid duplicates

  for (const city of LEBANESE_CITIES) {
    for (const [categoryName, types] of Object.entries(CATEGORY_TO_TYPES)) {
      try {
        onProgress?.(`Fetching ${categoryName} in ${city.name}...`);
        
        // Special handling for beaches
        const keyword = categoryName === "Beaches" ? "beach" : null;
        
        // Fetch first page
        let data = await searchPlaces(city, types, 5000, keyword);
        
        if (!data.results || data.results.length === 0) {
          onProgress?.(`No ${categoryName} found in ${city.name}`);
          continue;
        }

        // Process results
        let pageFetched = 0;
        let hasNextPage = true;
        
        while (hasNextPage && pageFetched < 3) { // Max 3 pages (60 results) per category/city
          if (data.results && data.results.length > 0) {
            // Transform Google Places data to match app structure
            const places = data.results
              .filter(place => !seenPlaceIds.has(place.place_id)) // Skip duplicates
              .map(place => {
                seenPlaceIds.add(place.place_id);
                
                // Calculate revenue proxy from price level (0-4 scale)
                const priceLevel = place.price_level || 0;
                const revenue = priceLevel > 0 ? priceLevel * 2500 : 0;
                
                // Get photo URL if available
                const photoUrl = place.photos && place.photos.length > 0
                  ? getPhotoUrl(place.photos[0].photo_reference)
                  : "";

                return {
                  Location: place.name,
                  Country: city.name,
                  Category: categoryName,
                  Visitors: place.user_ratings_total || 0,
                  Rating: place.rating || 0,
                  Revenue: revenue,
                  Accommodation_Available: categoryName === "Hotels" ? "Yes" : "No",
                  // Extra Google Places data
                  PlaceId: place.place_id,
                  Address: place.vicinity || "",
                  ImageUrl: photoUrl,
                  Latitude: place.geometry?.location?.lat || 0,
                  Longitude: place.geometry?.location?.lng || 0,
                  PriceLevel: priceLevel,
                  IsOpen: place.opening_hours?.open_now ?? null,
                  Types: place.types?.join(", ") || ""
                };
              });

            allPlaces.push(...places);
            totalFetched += places.length;
            
            onProgress?.(`Fetched ${totalFetched} places so far...`);
          }
          
          // Check if there's a next page
          if (data.next_page_token) {
            // Google requires a short delay before using next_page_token
            await new Promise(resolve => setTimeout(resolve, 2000));
            data = await searchPlaces(city, types, 5000, keyword, data.next_page_token);
            pageFetched++;
          } else {
            hasNextPage = false;
          }
        }
        
        // Be nice to the API - wait 1 second between category/city combinations
        await new Promise(resolve => setTimeout(resolve, 1000));
        
      } catch (error) {
        console.error(`Error fetching ${categoryName} in ${city.name}:`, error);
        onProgress?.(`Error: ${error.message}`);
        
        // If we hit quota limit, stop completely
        if (error.message.includes("quota")) {
          throw error;
        }
      }
    }
  }

  return allPlaces;
}

/**
 * Quick test function to verify API key works
 */
export async function testGooglePlacesConnection() {
  try {
    const beirut = { name: "Beirut", lat: 33.8886, lng: 35.4955 };
    const data = await searchPlaces(beirut, ["restaurant"], 5000);
    return {
      success: true,
      message: `Found ${data.results?.length || 0} restaurants in Beirut`,
      data: data.results
    };
  } catch (error) {
    return {
      success: false,
      message: error.message
    };
  }
}
