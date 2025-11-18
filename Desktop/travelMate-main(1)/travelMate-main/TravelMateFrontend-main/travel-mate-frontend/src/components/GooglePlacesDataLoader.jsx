import { useEffect, useState } from "react";
import { fetchAllLebanonPlaces, testGooglePlacesConnection } from "../services/googlePlacesService";

export default function GooglePlacesDataLoader({ onData }) {
  const [status, setStatus] = useState("Starting...");
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    async function loadData() {
      try {
        // First, test if API key works
        setStatus("Testing Google Places API connection...");
        const test = await testGooglePlacesConnection();
        
        if (!test.success) {
          setError(`API Error: ${test.message}. Check your API key and billing in Google Cloud Console.`);
          setIsLoading(false);
          return;
        }

        setStatus(`Connection OK! ${test.message}`);
        
        // Now fetch all places
        setStatus("Fetching all Lebanon places... This may take a few minutes.");
        
        const places = await fetchAllLebanonPlaces((progress) => {
          setStatus(progress);
        });

        setStatus(`✅ Successfully loaded ${places.length} places from Google Places!`);
        onData(places);
        setIsLoading(false);

      } catch (err) {
        setError(`Error: ${err.message}`);
        setIsLoading(false);
      }
    }

    loadData();
  }, [onData]);

  return (
    <div style={{
      padding: "20px",
      backgroundColor: isLoading ? "#fff3cd" : error ? "#f8d7da" : "#d4edda",
      border: "1px solid " + (isLoading ? "#ffc107" : error ? "#dc3545" : "#28a745"),
      borderRadius: "5px",
      marginBottom: "20px"
    }}>
      {isLoading && (
        <div>
          <strong>⏳ Loading data from Google Places API...</strong>
          <p style={{ margin: "10px 0", fontSize: "14px" }}>{status}</p>
          <div style={{
            width: "100%",
            height: "4px",
            backgroundColor: "#e9ecef",
            borderRadius: "2px",
            overflow: "hidden"
          }}>
            <div style={{
              width: "30%",
              height: "100%",
              backgroundColor: "#ffc107",
              animation: "loading 1.5s infinite"
            }}></div>
          </div>
          <style>{`
            @keyframes loading {
              0% { margin-left: 0; }
              50% { margin-left: 70%; }
              100% { margin-left: 0; }
            }
          `}</style>
        </div>
      )}
      
      {error && (
        <div>
          <strong>❌ Error loading data</strong>
          <p style={{ margin: "10px 0", fontSize: "14px", color: "#721c24" }}>{error}</p>
          <p style={{ fontSize: "12px", marginTop: "10px" }}>
            Make sure you've enabled billing and the Places API in Google Cloud Console:<br/>
            <a href="https://console.cloud.google.com/apis/dashboard" target="_blank" rel="noopener noreferrer">
              https://console.cloud.google.com/apis/dashboard
            </a>
          </p>
        </div>
      )}
      
      {!isLoading && !error && (
        <div>
          <strong>✅ Dataset loaded from Google Places!</strong>
          <p style={{ margin: "10px 0", fontSize: "14px" }}>{status}</p>
        </div>
      )}
    </div>
  );
}
