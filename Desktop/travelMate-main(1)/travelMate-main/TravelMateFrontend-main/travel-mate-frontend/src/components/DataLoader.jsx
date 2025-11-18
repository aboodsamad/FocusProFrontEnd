import { useEffect } from "react";
import * as d3 from "d3";

export default function DataLoader({ onData }) {
  useEffect(() => {
    const url = "/tourism_dataset.csv";
    d3.csv(url).then((raw) => {
      const cleaned = raw.map((r) => ({
        Location: r.Location,
        Country: r.Country,
        Category: r.Category,
        Visitors: +r.Visitors,
        Rating: +r.Rating,
        Revenue: +r.Revenue,
        Accommodation_Available: r.Accommodation_Available
      }));
      onData(cleaned);
    });
  }, [onData]);

  return <div><strong>Dataset loaded.</strong></div>;
}
