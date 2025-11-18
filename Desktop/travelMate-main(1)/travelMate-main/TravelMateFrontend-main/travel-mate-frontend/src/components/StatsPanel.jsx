import React, { useMemo } from "react";

export default function StatsPanel({ rows, field }) {
  const stats = useMemo(() => {
    if (!rows.length) return { avg: 0, min: 0, max: 0 };

    const values = rows.map(r => Number(r[field]) || 0);
    return {
      avg: (values.reduce((a, b) => a + b, 0) / values.length).toFixed(2),
      min: Math.min(...values).toFixed(2),
      max: Math.max(...values).toFixed(2),
    };
  }, [rows, field]);

  const cardStyle = {
    padding: "22px",
    borderRadius: "18px",
    color: "white",
    fontWeight: 600,
    boxShadow: "0px 4px 18px rgba(0,0,0,0.08)",
    textAlign: "center",
    fontSize: "20px",
  };

  return (
    <div
      style={{
        display: "grid",
        gridTemplateColumns: "repeat(3, 1fr)",
        gap: "20px",
      }}
    >

      {/* Average */}
      <div
        style={{
          ...cardStyle,
          background: "linear-gradient(135deg, #4facfe, #00f2fe)",
        }}
      >
        <div style={{ fontSize: "16px", opacity: 0.9 }}>Average {field}</div>
        <div style={{ fontSize: "32px", marginTop: "6px" }}>{stats.avg}</div>
      </div>

      {/* Min */}
      <div
        style={{
          ...cardStyle,
          background: "linear-gradient(135deg, #f6d365, #fda085)",
        }}
      >
        <div style={{ fontSize: "16px", opacity: 0.9 }}>Min {field}</div>
        <div style={{ fontSize: "32px", marginTop: "6px" }}>{stats.min}</div>
      </div>

      {/* Max */}
      <div
        style={{
          ...cardStyle,
          background: "linear-gradient(135deg, #a18cd1, #fbc2eb)",
        }}
      >
        <div style={{ fontSize: "16px", opacity: 0.9 }}>Max {field}</div>
        <div style={{ fontSize: "32px", marginTop: "6px" }}>{stats.max}</div>
      </div>

    </div>
  );
}
