import React, { useState, useRef, useEffect } from "react";

export default function CustomDropdown({ label, value, onChange, options }) {
  const [open, setOpen] = useState(false);
  const ref = useRef();

  // Close when clicking outside
  useEffect(() => {
    const handler = (e) => {
      if (ref.current && !ref.current.contains(e.target)) setOpen(false);
    };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, []);

  return (
    <div style={{ marginBottom: 20 }} ref={ref}>
      <label
        style={{
          display: "block",
          fontWeight: 600,
          color: "#03446A",
          marginBottom: 6,
          fontSize: 14,
        }}
      >
        {label}
      </label>

      {/* Selected Box */}
      <div
        onClick={() => setOpen(!open)}
        style={{
          padding: "12px 14px",
          background: "white",
          borderRadius: "12px",
          border: "1px solid #cfd8dc",
          boxShadow: "0 2px 8px rgba(0,0,0,0.05)",
          cursor: "pointer",
          userSelect: "none",
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
        }}
      >
        <span>{value || "All"}</span>
        <span style={{ transform: open ? "rotate(180deg)" : "none", transition: "0.2s" }}>
          ▼
        </span>
      </div>

      {/* Dropdown menu */}
      {open && (
        <div
          style={{
            marginTop: 8,
            background: "white",
            borderRadius: "12px",
            border: "1px solid #cfd8dc",
            boxShadow: "0 8px 25px rgba(0,0,0,0.15)",
            maxHeight: "200px",
            overflowY: "auto",
            animation: "fadeIn 0.2s ease-out",
            zIndex: 10,
            position: "relative",
          }}
        >
          {/* ALL option */}
          <div
            onClick={() => {
              onChange("");
              setOpen(false);
            }}
            style={{
              padding: "12px",
              cursor: "pointer",
              borderBottom: "1px solid #f1f1f1",
              fontWeight: value === "" ? 700 : 400,
              background: value === "" ? "#e3f2fd" : "white",
            }}
          >
            All
          </div>

          {/* List options */}
          {options.map((opt) => (
            <div
              key={opt}
              onClick={() => {
                onChange(opt);
                setOpen(false);
              }}
              style={{
                padding: "12px",
                cursor: "pointer",
                transition: "0.2s",
                background: value === opt ? "#e3f2fd" : "white",
              }}
              onMouseEnter={(e) => (e.target.style.background = "#f5faff")}
              onMouseLeave={(e) =>
                (e.target.style.background = value === opt ? "#e3f2fd" : "white")
              }
            >
              {opt}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
