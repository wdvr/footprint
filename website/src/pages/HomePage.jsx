import { Link } from 'react-router-dom'
import {
  FiGlobe,
  FiMapPin,
  FiWifi,
  FiShield,
  FiUsers,
  FiSmartphone,
  FiGithub,
  FiCoffee,
  FiMessageCircle,
  FiDownload
} from 'react-icons/fi'
import { BsApple } from 'react-icons/bs'

function HomePage() {
  const features = [
    {
      icon: <FiGlobe />,
      title: 'Interactive World Map',
      description: 'Tap to mark countries and regions with beautiful MapKit integration and smooth animations.'
    },
    {
      icon: <FiMapPin />,
      title: '195+ Regions',
      description: 'Track all UN countries, US states, and Canadian provinces with accurate geographic boundaries.'
    },
    {
      icon: <FiWifi />,
      title: 'Offline First',
      description: 'Works perfectly without internet. Your data syncs automatically when you\'re back online.'
    },
    {
      icon: <FiShield />,
      title: 'Privacy Focused',
      description: 'Sign in with Apple. No email collection, minimal data, your travels stay yours.'
    },
    {
      icon: <FiUsers />,
      title: 'Share with Friends',
      description: 'Connect with friends, compare adventures, and discover common destinations.'
    },
    {
      icon: <FiSmartphone />,
      title: 'iOS Widget',
      description: 'See your travel stats at a glance with beautiful home screen widgets.'
    }
  ]

  const stats = [
    { number: '195', label: 'Countries' },
    { number: '50', label: 'US States' },
    { number: '13', label: 'CA Provinces' },
    { number: '100%', label: 'Free' }
  ]

  return (
    <>
      {/* Hero Section */}
      <section className="hero">
        <div className="container">
          <div className="hero-content">
            <div className="hero-text animate-slide-up">
              <h1>
                See the world.
                <br />
                <span className="text-gradient">Track your travels.</span>
              </h1>
              <p>
                A beautiful iOS app for tracking your adventures on an interactive world map.
                Mark countries, states, and provinces you've visited. Share your journey.
              </p>
              <div className="hero-buttons">
                <a
                  href="https://apps.apple.com"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="btn btn-primary"
                >
                  <BsApple size={20} />
                  Download on App Store
                </a>
                <a
                  href="https://github.com/wdvr/footprint"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="btn btn-secondary"
                >
                  <FiGithub size={20} />
                  View on GitHub
                </a>
              </div>
            </div>

            <div className="hero-visual animate-float">
              <div className="iphone-mockup">
                <div className="iphone-screen">
                  <div className="iphone-notch"></div>
                  <div className="iphone-placeholder">
                    <div className="iphone-placeholder-icon">
                      <FiGlobe size={64} />
                    </div>
                    <p>App Screenshot<br />Coming Soon</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Stats Section */}
      <section className="container">
        <div className="stats">
          {stats.map((stat, index) => (
            <div key={index} className="stat-item">
              <div className="stat-number">{stat.number}</div>
              <div className="stat-label">{stat.label}</div>
            </div>
          ))}
        </div>
      </section>

      {/* Features Section */}
      <section className="features" id="features">
        <div className="container">
          <div className="section-header">
            <h2>Everything you need to <span className="text-gradient">track your travels</span></h2>
            <p>Simple, beautiful, and built for travelers who want to remember every adventure.</p>
          </div>

          <div className="features-grid">
            {features.map((feature, index) => (
              <div key={index} className="card feature-card">
                <div className="feature-icon">{feature.icon}</div>
                <h3>{feature.title}</h3>
                <p>{feature.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Support Section */}
      <section className="support-section" id="donate">
        <div className="container">
          <div className="section-header">
            <h2>Support <span className="text-gradient">Footprint</span></h2>
            <p>Footprint is free and open source. Here's how you can help!</p>
          </div>

          <div className="support-grid">
            <div className="card support-card">
              <div className="support-icon github">
                <FiGithub />
              </div>
              <h3>Star on GitHub</h3>
              <p>Show your support by starring the repo. It helps others discover Footprint!</p>
              <a
                href="https://github.com/wdvr/footprint"
                target="_blank"
                rel="noopener noreferrer"
                className="btn btn-secondary"
              >
                <FiGithub /> View Repository
              </a>
            </div>

            <div className="card support-card">
              <div className="support-icon coffee">
                <FiCoffee />
              </div>
              <h3>Buy Me a Coffee</h3>
              <p>Help fund development, server costs, and my Claude subscription!</p>
              <a
                href="https://buymeacoffee.com"
                target="_blank"
                rel="noopener noreferrer"
                className="btn btn-secondary"
              >
                <FiCoffee /> Donate
              </a>
            </div>

            <div className="card support-card">
              <div className="support-icon feedback">
                <FiMessageCircle />
              </div>
              <h3>Send Feedback</h3>
              <p>Found a bug? Have a feature idea? We'd love to hear from you!</p>
              <Link to="/feedback" className="btn btn-secondary">
                <FiMessageCircle /> Send Feedback
              </Link>
            </div>
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="cta">
        <div className="container">
          <div className="cta-box">
            <h2>Ready to start tracking?</h2>
            <p>Download Footprint for free and begin your travel journey today.</p>
            <div className="cta-buttons">
              <a
                href="https://apps.apple.com"
                target="_blank"
                rel="noopener noreferrer"
                className="btn btn-white"
              >
                <BsApple size={20} />
                Download for iOS
              </a>
              <Link to="/feedback" className="btn btn-outline-white">
                <FiMessageCircle />
                Get in Touch
              </Link>
            </div>
          </div>
        </div>
      </section>
    </>
  )
}

export default HomePage
