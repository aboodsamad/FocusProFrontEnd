import { useEffect, useState } from "react";

export default function YelpDataLoader({ onData }) {
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    async function loadData() {
      try {
        
        // Load from the JSON file you just saved
        const response = await fetch('/lebanon_google_places.json');
        
        if (!response.ok) {
          throw new Error('Failed to load data file');
        }
        
        const places = await response.json();
        
        onData(places);
        setIsLoading(false);

      } catch (err) {
        setError(`Error: ${err.message}`);
        setIsLoading(false);
      }
    }

    loadData();
  }, [onData]);

 
}