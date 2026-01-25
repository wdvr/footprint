import { useState } from 'react'
import { Outlet, Link } from 'react-router-dom'
import { FiMenu, FiX, FiGithub } from 'react-icons/fi'

function Layout() {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh' }}>
      {/* Header */}
      <header className="header">
        <div className="container">
          <div className="header-content">
            <Link to="/" className="logo">
              <img src="/globe.svg" alt="Footprint" className="logo-icon" />
              <span className="text-gradient">Footprint</span>
            </Link>

            <nav className={`nav ${mobileMenuOpen ? 'open' : ''}`}>
              <Link to="/" className="nav-link" onClick={() => setMobileMenuOpen(false)}>Home</Link>
              <Link to="/feedback" className="nav-link" onClick={() => setMobileMenuOpen(false)}>Feedback</Link>
              <a
                href="https://github.com/wdvr/footprint"
                target="_blank"
                rel="noopener noreferrer"
                className="open-source-badge"
              >
                <FiGithub /> Open Source
              </a>
            </nav>

            <button
              className="mobile-menu-btn"
              onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
              aria-label="Toggle menu"
            >
              {mobileMenuOpen ? <FiX /> : <FiMenu />}
            </button>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main style={{ flex: 1 }}>
        <Outlet />
      </main>

      {/* Footer */}
      <footer className="footer">
        <div className="container">
          <div className="footer-content">
            <div className="footer-brand">
              <Link to="/" className="logo" style={{ color: 'white' }}>
                <img src="/globe.svg" alt="Footprint" className="logo-icon" />
                <span>Footprint</span>
              </Link>
              <p>Track your travels around the world. Mark countries, states, and provinces you've visited on an interactive map.</p>
            </div>

            <div className="footer-section">
              <h4>App</h4>
              <ul className="footer-links">
                <li><a href="#features">Features</a></li>
                <li><a href="https://apps.apple.com" target="_blank" rel="noopener noreferrer">App Store</a></li>
                <li><Link to="/feedback">Feedback</Link></li>
              </ul>
            </div>

            <div className="footer-section">
              <h4>Legal</h4>
              <ul className="footer-links">
                <li><Link to="/privacy">Privacy Policy</Link></li>
                <li><Link to="/terms">Terms of Service</Link></li>
                <li><Link to="/license">License</Link></li>
              </ul>
            </div>

            <div className="footer-section">
              <h4>Connect</h4>
              <ul className="footer-links">
                <li><a href="https://github.com/wdvr/footprint" target="_blank" rel="noopener noreferrer">GitHub</a></li>
                <li><a href="#donate">Support Us</a></li>
              </ul>
            </div>
          </div>

          <div className="footer-bottom">
            <p>&copy; {new Date().getFullYear()} Footprint. All rights reserved.</p>
            <div className="social-links">
              <a href="https://github.com/wdvr/footprint" target="_blank" rel="noopener noreferrer" aria-label="GitHub">
                <FiGithub />
              </a>
            </div>
          </div>
        </div>
      </footer>
    </div>
  )
}

export default Layout
