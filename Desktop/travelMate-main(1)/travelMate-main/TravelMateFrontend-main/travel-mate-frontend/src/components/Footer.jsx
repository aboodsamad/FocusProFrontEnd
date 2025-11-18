
export default function Footer() {
  return (
    <footer style={{ textAlign: "center", marginTop: 40, padding: 20}} className="site-footer">
      © {new Date().getFullYear()} <strong>TravelMate</strong> — All rights reserved.
    </footer>
  );
}
