import React, { useState, useMemo } from "react";
import YelpDataLoader from "../components/YelpDataLoader.jsx";
import FilterPanel from "../components/FilterPanel.jsx";
import StatsPanel from "../components/StatsPanel.jsx";
import BarChart from "../components/BarChart.jsx";

export default function Dashboard({ data, setData }) {
  const [country, setCountry] = useState("");
  const [category, setCategory] = useState("");
  const [statsField, setStatsField] = useState("Rating");
  const [chartField, setChartField] = useState("Visitors");

  const filtered = useMemo(() => {
    return data.filter((row) =>
      (country ? row.Country === country : true) &&
      (category ? row.Category === category : true)
    );
  }, [data, country, category]);

  return (
    <div style={{ fontFamily: "Inter, sans-serif", padding: 20 }} className="app-container">
      <div
  style={{
    width: "100%",
    padding: "30px 0 40px",
    marginBottom: "10px",
    background: "linear-gradient(135deg, rgba(0,160,255,0.15), rgba(255,255,255,0))",
    backdropFilter: "blur(4px)",
  }}
>

  <div
    style={{
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      gap: "16px",
    }}
  >
    <span style={{ fontSize: "38px" }}>🌍</span>


    <h1
      style={{
        margin: 0,
        fontSize: "34px",
        fontWeight: 800,
        background: "linear-gradient(90deg, #014f86, #1b6fa8)",
        WebkitBackgroundClip: "text",
        color: "transparent",
        letterSpacing: "0.6px",
      }}
    >
      Lebanon Tourism Dashboard
    </h1>

    <img
      src="https://img.icons8.com/color/48/lebanon.png"
      alt="Lebanon"
      style={{ width: 40, height: 40, filter: "drop-shadow(0 2px 4px rgba(0,0,0,0.2))" }}
    />
  </div>

  <p
    style={{
      textAlign: "center",
      marginTop: "14px",
      fontSize: "15px",
      color: "#01497c",
      opacity: 0.8,
      letterSpacing: "0.3px",
    }}
  >
    Explore insights, ratings, and tourism trends across Lebanon 🌴
  </p>
</div>

      <YelpDataLoader onData={setData} />

      <div style={{ display: "grid", gridTemplateColumns: "250px 1fr", gap: 20 }} className="dashboard-grid">
        <FilterPanel className="filters-panel"
          data={data}
          country={country}
          setCountry={setCountry}
          category={category}
          setCategory={setCategory}
        />
        <div style={{ display: "grid", gap: 20 }}>
          <StatsPanel rows={filtered} field={statsField} />
          <BarChart rows={filtered} field={chartField} />
        </div>
      </div>
    </div>
  );
}
