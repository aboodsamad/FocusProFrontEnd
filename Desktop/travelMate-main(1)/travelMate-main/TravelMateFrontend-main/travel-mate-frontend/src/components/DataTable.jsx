import { useState, useMemo } from "react";

export default function DataTable({ rows }) {
  const [page, setPage] = useState(1);
  const rowsPerPage = 10;

  if (!rows.length) return <div>No data found.</div>;

  const headers = Object.keys(rows[0]);
  const totalPages = Math.ceil(rows.length / rowsPerPage);

  const currentRows = useMemo(() => {
    const start = (page - 1) * rowsPerPage;
    return rows.slice(start, start + rowsPerPage);
  }, [rows, page]);

  const handlePrev = () => setPage((p) => Math.max(p - 1, 1));
  const handleNext = () => setPage((p) => Math.min(p + 1, totalPages));

  return (
    <div style={{ overflow: "auto", border: "1px solid #ddd", borderRadius: 6 }}>
      <table width="100%" cellPadding="6">
        <thead>
          <tr style={{ background: "#f3f4f6" }}>
            {headers.map((h) => (
              <th key={h}>{h}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {currentRows.map((r, i) => (
            <tr key={i}>
              {headers.map((h) => (
                <td key={h}>{r[h]}</td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>

      <div
        style={{
          display: "flex",
          justifyContent: "center",
          alignItems: "center",
          gap: "1rem",
          padding: "1rem",
          borderTop: "1px solid #ddd",
          background: "#fafafa",
        }}
      >
        <button onClick={handlePrev} disabled={page === 1}>
          ◀ Prev
        </button>
        <span>
          Page {page} of {totalPages}
        </span>
        <button onClick={handleNext} disabled={page === totalPages}>
          Next ▶
        </button>
      </div>
    </div>
  );
}
