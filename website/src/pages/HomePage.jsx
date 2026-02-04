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
  FiDownload,
  FiCamera,
  FiCalendar,
  FiMail,
  FiTrendingUp
} from 'react-icons/fi'
import { BsApple } from 'react-icons/bs'

function HomePage() {
  const features = [
    {
      icon: <FiGlobe />,
      title: 'Interactive World Map',
      description: 'Beautiful MapKit integration with smooth animations. Tap to mark countries you\'ve explored.'
    },
    {
      icon: <FiCamera />,
      title: 'Import from Photos',
      description: 'Automatically discover places you\'ve been from your photo library\'s location data.'
    },
    {
      icon: <FiCalendar />,
      title: 'Google Calendar Import',
      description: 'Import your travel history from Google Calendar events - flights, hotels, and trips.'
    },
    {
      icon: <FiMail />,
      title: 'Gmail Import',
      description: 'Extract travel data from flight confirmations and booking emails in your inbox.'
    },
    {
      icon: <FiWifi />,
      title: 'Offline First',
      description: 'Works perfectly without internet. Your data syncs automatically when you\'re back online.'
    },
    {
      icon: <FiUsers />,
      title: 'Share with Friends',
      description: 'Connect with friends, compare adventures, and see who\'s visited the most places.'
    }
  ]

  const moreFeatures = [
    {
      icon: <FiMapPin />,
      title: '195+ Regions',
      description: 'Track all UN countries, US states, and Canadian provinces with accurate geographic boundaries.'
    },
    {
      icon: <FiTrendingUp />,
      title: 'Travel Stats',
      description: 'See your progress with beautiful statistics - continents, timezones, and achievements.'
    },
    {
      icon: <FiShield />,
      title: 'Privacy Focused',
      description: 'Sign in with Apple. No email collection, minimal data, your travels stay yours.'
    },
    {
      icon: <FiSmartphone />,
      title: 'iOS Widgets',
      description: 'See your travel stats at a glance with beautiful home screen widgets.'
    }
  ]

  const stats = [
    { number: '195', label: 'Countries' },
    { number: '50', label: 'US States' },
    { number: '13', label: 'CA Provinces' },
    { number: '7', label: 'Continents' }
  ]

  return (
    <>
      {/* Hero Section */}
      <section className="hero">
        <div className="container">
          <div className="hero-content">
            <div className="hero-text animate-slide-up">
              <h1>
                Your travels.
                <br />
                <span className="text-gradient">Beautifully mapped.</span>
              </h1>
              <p>
                Track countries, US states, and Canadian provinces on an interactive world map.
                Import from photos, Google Calendar, and Gmail. Share with friends and compare stats.
              </p>
              <div className="hero-buttons">
                <a
                  href="https://apps.apple.com/app/footprint-travel-tracker"
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
                  <img
                    src="/screenshot-iphone.png"
                    alt="Footprint app showing world map with visited countries"
                    className="iphone-screenshot"
                  />
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
            <h2>Smart import. <span className="text-gradient">Zero effort.</span></h2>
            <p>Import your travel history automatically from your photos, calendar, and email.</p>
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

      {/* More Features Section */}
      <section className="features">
        <div className="container">
          <div className="section-header">
            <h2>And so much <span className="text-gradient">more</span></h2>
            <p>Built for travelers who want to remember every adventure.</p>
          </div>

          <div className="features-grid features-grid-4">
            {moreFeatures.map((feature, index) => (
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
            <h2>Start mapping your adventures</h2>
            <p>Download Footprint for free. Import your travel history in seconds.</p>
            <div className="cta-buttons">
              <a
                href="https://apps.apple.com/app/footprint-travel-tracker"
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
