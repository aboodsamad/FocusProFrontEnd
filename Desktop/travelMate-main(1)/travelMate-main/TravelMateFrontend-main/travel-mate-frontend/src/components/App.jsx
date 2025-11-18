import { BrowserRouter, Routes, Route } from "react-router-dom";
import { useState } from "react";
import Header from "./Header.jsx";
import Footer from "./Footer.jsx";
import Dashboard from "../pages/Dashboard.jsx";
import DataTablePage from "../pages/DataTablePage.jsx";

export default function App() {
  const [data, setData] = useState([]);

  return (
    <BrowserRouter>
      <Header />
      <Routes>
        <Route path="/" element={<Dashboard data={data} setData={setData} />} />
        <Route path="/data-table" element={<DataTablePage rows={data} />} />
      </Routes>
      <Footer />
    </BrowserRouter>
  );
}
