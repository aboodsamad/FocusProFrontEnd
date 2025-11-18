import { Bar } from "react-chartjs-2";
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  BarElement,
  Title,
  Tooltip,
  Legend
} from "chart.js";

ChartJS.register(CategoryScale, LinearScale, BarElement, Title, Tooltip, Legend);

export default function BarChart({ rows, field }) {
  if (!rows.length) return <div>No data available for chart.</div>;

  const top10 = rows.slice(0, 10);
  const labels = top10.map((r) => r.Location);
  const values = top10.map((r) => +r[field]);

  const data = {
    labels,
    datasets: [
      {
        label: field,
        data: values,
        backgroundColor: "rgba(37, 99, 235, 0.6)"
      }
    ]
  };

  const options = {
    responsive: true,
    plugins: { legend: { position: "top" }, title: { display: true, text: `Top 10 by ${field}` } }
  };

  return (
  <div
    style={{
      background: "linear-gradient(135deg, #e3f2fd, #f5faff)",
      padding: "32px",
      borderRadius: "22px",
      boxShadow: "0 12px 32px rgba(0,0,0,0.12)",
      backdropFilter: "blur(8px)",
      border: "1px solid rgba(255,255,255,0.6)",
      marginTop: "10px",
    }}
  >
    <h2
      style={{
        marginBottom: "20px",
        color: "#01579b",
        fontSize: "22px",
        fontWeight: "700",
        letterSpacing: "0.4px",
        textAlign: "center",
      }}
    >
      Top 10 by {field}
    </h2>

    <div style={{ width: "100%", height: "380px" }}>
      <Bar data={data} options={options} />
    </div>
  </div>
);

}
