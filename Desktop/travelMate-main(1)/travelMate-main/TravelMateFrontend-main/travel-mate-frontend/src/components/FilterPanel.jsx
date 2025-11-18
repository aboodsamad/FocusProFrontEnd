import CustomDropdown from "./CustomDropdown.jsx";

export default function FilterPanel({
  data,
  country,
  setCountry,
  category,
  setCategory,
}) {
  const countries = Array.from(new Set(data.map((d) => d.Country))).sort();
  const categories = Array.from(new Set(data.map((d) => d.Category))).sort();

  const panelStyle = {
    background: "linear-gradient(135deg, #e0f7fa, #e3f2fd)",
    padding: "24px",
    borderRadius: "20px",
    boxShadow: "0 8px 25px rgba(0,0,0,0.08)",
    backdropFilter: "blur(8px)",
    border: "1px solid rgba(255,255,255,0.4)",
  };

  return (
    <div style={panelStyle}>
      <h3 style={{ color: "#01579b", marginBottom: "20px" }}>Filters</h3>

      <CustomDropdown
        label="Country"
        value={country}
        onChange={setCountry}
        options={countries}
      />

      <CustomDropdown
        label="Category"
        value={category}
        onChange={setCategory}
        options={categories}
      />
    </div>
  );
}
