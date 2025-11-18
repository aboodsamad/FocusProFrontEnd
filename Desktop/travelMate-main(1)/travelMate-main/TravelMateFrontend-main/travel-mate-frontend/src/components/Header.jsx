import { Link } from "react-router-dom";
import "./Header.css";

export default function Header() {
  return (
    <header className="header">
      <div className="logo">TravelMate</div>
      <nav className="nav-links">
        <Link to="/">Dashboard</Link>
        <Link to="/data-table">Data Table</Link>
      </nav>
    </header>
  );
}
