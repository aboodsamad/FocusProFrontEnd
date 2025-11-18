// Google Places API Service using Maps JavaScript API (NO CORS issues!)

// Expanded list of Lebanese cities and towns
const LEBANESE_CITIES = [
  // Major cities
  { name: "Beirut", lat: 33.8886, lng: 35.4955 },
  { name: "Tripoli", lat: 34.4333, lng: 35.8500 },
  { name: "Sidon", lat: 33.5630, lng: 35.3688 },
  { name: "Tyre", lat: 33.2733, lng: 35.2039 },
  { name: "Zahle", lat: 33.8462, lng: 35.9015 },
  
  // Mount Lebanon
  { name: "Jounieh", lat: 33.9808, lng: 35.6178 },
  { name: "Byblos", lat: 34.1184, lng: 35.6484 },
  { name: "Batroun", lat: 34.2550, lng: 35.6586 },
  { name: "Jbeil", lat: 34.1212, lng: 35.6481 },
  { name: "Baabda", lat: 33.8333, lng: 35.5333 },
  { name: "Aley", lat: 33.8000, lng: 35.5833 },
  { name: "Bikfaya", lat: 33.9167, lng: 35.6667 },
  { name: "Broummana", lat: 33.8833, lng: 35.6500 },
  { name: "Beit Mery", lat: 33.8500, lng: 35.6167 },
  { name: "Ain Saadeh", lat: 33.8833, lng: 35.6167 },
  
  // North Lebanon  
  { name: "Zgharta", lat: 34.3833, lng: 35.8667 },
  { name: "Bcharreh", lat: 34.2500, lng: 36.0167 },
  { name: "Koura", lat: 34.3167, lng: 35.7333 },
  { name: "Minieh", lat: 34.4500, lng: 35.8333 },
  { name: "Chekka", lat: 34.3167, lng: 35.7000 },
  
  // South Lebanon
  { name: "Nabatieh", lat: 33.3769, lng: 35.4839 },
  { name: "Jezzine", lat: 33.5500, lng: 35.5833 },
  { name: "Marjeyoun", lat: 33.3581, lng: 35.5897 },
  { name: "Bent Jbeil", lat: 33.1167, lng: 35.4333 },
  
  // Bekaa Valley
  { name: "Baalbek", lat: 34.0059, lng: 36.2081 },
  { name: "Chtaura", lat: 33.8167, lng: 35.8500 },
  { name: "Rayak", lat: 33.8500, lng: 35.9167 },
  { name: "Anjar", lat: 33.7272, lng: 35.9294 },
  { name: "Kab Elias", lat: 33.8167, lng: 35.8667 },
  { name: "Bar Elias", lat: 33.8000, lng: 35.9000 },
  
  // Additional tourist spots
  { name: "Faraya", lat: 34.0667, lng: 35.8333 },
  { name: "Cedars", lat: 34.2833, lng: 36.0000 },
  { name: "Harissa", lat: 33.9833, lng: 35.6500 },
  { name: "Jeita", lat: 33.9489, lng: 35.6414 },
  { name: "Beiteddine", lat: 33.6833, lng: 35.5833 },
  { name: "Deir el Qamar", lat: 33.6833, lng: 35.5500 }
];

const CATEGORY_TO_TYPES = {
  "Restaurants": "restaurant",
  "Cafes": "cafe",
  "Hotels": "lodging",
  "Beaches": "beach",
  "Tours": "travel_agency",
  "Landmarks": "tourist_attraction",
  "Museums": "museum",
  "Nightlife": "night_club",
  "Bars": "bar",
  "Parks": "park",
  "Shopping": "shopping_mall",
  "Bakery": "bakery",
  "Spa": "spa",
  "Gym": "gym",
  "Hospital": "hospital",
  "Bank": "bank",
  "Pharmacy": "pharmacy",
  "Gas Station": "gas_station",
  "Supermarket": "supermarket",
  "Church": "church",
  "Mosque": "mosque"
};

// Create a hidden map element for the Places Service
let mapElement = null;
let placesService = null;

function initPlacesService() {
  if (!placesService) {
    if (!mapElement) {
      mapElement = document.createElement('div');
      document.body.appendChild(mapElement);
    }
    
    const map = new google.maps.Map(mapElement);
    placesService = new google.maps.places.PlacesService(map);
  }
  return placesService;
}

/**
 * Search for places using Google Places Service
 */
function searchPlaces(location, type, radius = 5000) {
  return new Promise((resolve, reject) => {
    const service = initPlacesService();
    
    const request = {
      location: { lat: location.lat, lng: location.lng },
      radius: radius,
      type: type
    };

    service.nearbySearch(request, (results, status) => {
      if (status === google.maps.places.PlacesServiceStatus.OK) {
        resolve(results);
      } else if (status === google.maps.places.PlacesServiceStatus.ZERO_RESULTS) {
        resolve([]);
      } else {
        reject(new Error(`Places API error: ${status}`));
      }
    });
  });
}

/**
 * Fetch all places from Lebanon
 */
export async function fetchAllLebanonPlaces(onProgress) {
  const allPlaces = [];
  let totalFetched = 0;
  const seenPlaceIds = new Set();

  for (const city of LEBANESE_CITIES) {
    for (const [categoryName, type] of Object.entries(CATEGORY_TO_TYPES)) {
      try {
        onProgress?.(`Fetching ${categoryName} in ${city.name}...`);
        
        const results = await searchPlaces(city, type, 5000);
        
        if (results.length === 0) {
          onProgress?.(`No ${categoryName} found in ${city.name}`);
          continue;
        }

        const places = results
          .filter(place => !seenPlaceIds.has(place.place_id))
          .map(place => {
            seenPlaceIds.add(place.place_id);
            
            const priceLevel = place.price_level || 0;
            const revenue = priceLevel > 0 ? priceLevel * 2500 : 0;

            return {
              Location: place.name,
              Country: city.name,
              Category: categoryName,
              Visitors: place.user_ratings_total || 0,
              Rating: place.rating || 0,
              Revenue: revenue,
              Accommodation_Available: categoryName === "Hotels" ? "Yes" : "No",
              PlaceId: place.place_id,
              Address: place.vicinity || "",
              ImageUrl: place.photos && place.photos.length > 0 
                ? place.photos[0].getUrl({ maxWidth: 400 })
                : "",
              Latitude: place.geometry.location.lat(),
              Longitude: place.geometry.location.lng(),
              PriceLevel: priceLevel,
              IsOpen: place.opening_hours?.open_now ?? null,
              Types: place.types?.join(", ") || ""
            };
          });

        allPlaces.push(...places);
        totalFetched += places.length;
        
        onProgress?.(`Fetched ${totalFetched} places so far...`);
        
        // Wait between requests to avoid rate limits
        await new Promise(resolve => setTimeout(resolve, 1000));
        
      } catch (error) {
        console.error(`Error fetching ${categoryName} in ${city.name}:`, error);
        onProgress?.(`Error: ${error.message}`);
      }
    }
  }

  return allPlaces;
}

/**
 * Quick test function to verify API works
 */
export async function testYelpConnection() {
  try {
    const beirut = { name: "Beirut", lat: 33.8886, lng: 35.4955 };
    const results = await searchPlaces(beirut, "restaurant", 5000);
    return {
      success: true,
      message: `Found ${results.length} restaurants in Beirut`,
      data: results
    };
  } catch (error) {
    return {
      success: false,
      message: error.message
    };
  }
}