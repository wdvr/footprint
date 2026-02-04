import { FiMail, FiMessageCircle, FiGithub, FiHelpCircle, FiBook } from 'react-icons/fi'

function SupportPage() {
  return (
    <div className="page-content">
      <div className="container">
        <div className="page-header">
          <h1>Support</h1>
          <p>We're here to help! Get in touch with us.</p>
        </div>

        <div className="support-options">
          {/* Email Support Card */}
          <div className="card support-card-large">
            <div className="support-icon email">
              <FiMail />
            </div>
            <h2>Email Support</h2>
            <p>
              Have a question, found a bug, or want to request a feature?
              Send us an email and we'll get back to you as soon as possible.
            </p>
            <a
              href="mailto:support@footprintmaps.com"
              className="btn btn-primary"
            >
              <FiMail /> support@footprintmaps.com
            </a>
          </div>

          {/* Other Support Options */}
          <div className="support-grid-small">
            <div className="card support-card">
              <div className="support-icon github">
                <FiGithub />
              </div>
              <h3>GitHub Issues</h3>
              <p>Report bugs or request features on our GitHub repository.</p>
              <a
                href="https://github.com/wdvr/footprint/issues"
                target="_blank"
                rel="noopener noreferrer"
                className="btn btn-secondary"
              >
                <FiGithub /> Open Issue
              </a>
            </div>

            <div className="card support-card">
              <div className="support-icon feedback">
                <FiMessageCircle />
              </div>
              <h3>Feedback</h3>
              <p>Share your thoughts and help us improve Footprint.</p>
              <a href="/feedback" className="btn btn-secondary">
                <FiMessageCircle /> Send Feedback
              </a>
            </div>
          </div>
        </div>

        {/* FAQ Section */}
        <div className="faq-section">
          <h2><FiHelpCircle /> Frequently Asked Questions</h2>

          <div className="faq-list">
            <div className="faq-item">
              <h3>How do I import my travel history from photos?</h3>
              <p>
                Go to Settings → Import Sources → Apple Photos. Footprint will scan your photo library
                for images with GPS location data and automatically mark the countries you've visited.
              </p>
            </div>

            <div className="faq-item">
              <h3>Is my data private?</h3>
              <p>
                Yes! Footprint uses Sign in with Apple and stores your data securely. We don't collect
                your email address or share your travel data with anyone. Your travels stay yours.
              </p>
            </div>

            <div className="faq-item">
              <h3>Does Footprint work offline?</h3>
              <p>
                Absolutely! Footprint is built offline-first. All your data is stored locally on your
                device and syncs automatically when you're back online.
              </p>
            </div>

            <div className="faq-item">
              <h3>How do I delete my account?</h3>
              <p>
                Go to Settings → Account → Delete Account. This will permanently remove all your data
                from our servers. Your local data can be cleared by deleting the app.
              </p>
            </div>

            <div className="faq-item">
              <h3>Can I share my travel map with friends?</h3>
              <p>
                Yes! You can add friends in the app and compare your travel statistics. You can also
                export your map as an image to share on social media.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

export default SupportPage
