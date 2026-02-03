import { useState } from 'react'
import { FiSend, FiCheckCircle, FiAlertCircle } from 'react-icons/fi'

const API_URL = import.meta.env.VITE_API_URL || 'https://api.footprintmaps.com'

function FeedbackPage() {
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    type: 'feedback',
    message: ''
  })
  const [status, setStatus] = useState('idle') // idle, loading, success, error
  const [errorMessage, setErrorMessage] = useState('')

  const handleChange = (e) => {
    const { name, value } = e.target
    setFormData(prev => ({ ...prev, [name]: value }))
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    setStatus('loading')
    setErrorMessage('')

    try {
      const response = await fetch(`${API_URL}/v1/feedback/public`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          ...formData,
          timestamp: new Date().toISOString(),
          source: 'website'
        })
      })

      if (!response.ok) {
        throw new Error('Failed to submit feedback')
      }

      setStatus('success')
      setFormData({ name: '', email: '', type: 'feedback', message: '' })
    } catch (error) {
      console.error('Feedback submission error:', error)
      setStatus('error')
      setErrorMessage('Failed to submit feedback. Please try again or contact us on GitHub.')
    }
  }

  if (status === 'success') {
    return (
      <div className="feedback-page">
        <div className="container">
          <div className="feedback-content">
            <div className="feedback-form">
              <div className="form-success">
                <FiCheckCircle className="form-success-icon" />
                <h2>Thank you!</h2>
                <p style={{ color: 'var(--text-muted)', marginBottom: 'var(--spacing-xl)' }}>
                  Your feedback has been received. We appreciate you taking the time to help
                  improve Footprint!
                </p>
                <button
                  className="btn btn-primary"
                  onClick={() => setStatus('idle')}
                >
                  Send Another Message
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="feedback-page">
      <div className="container">
        <div className="feedback-content">
          <div className="section-header" style={{ marginBottom: 'var(--spacing-2xl)' }}>
            <h1>Send <span className="text-gradient">Feedback</span></h1>
            <p>
              Found a bug? Have a feature request? Just want to say hi? We'd love to hear from you!
            </p>
          </div>

          <form className="feedback-form" onSubmit={handleSubmit}>
            {status === 'error' && (
              <div style={{
                background: 'rgba(251, 113, 133, 0.1)',
                border: '1px solid var(--coral)',
                borderRadius: 'var(--radius)',
                padding: 'var(--spacing-md)',
                marginBottom: 'var(--spacing-lg)',
                display: 'flex',
                alignItems: 'center',
                gap: 'var(--spacing-sm)',
                color: 'var(--coral)'
              }}>
                <FiAlertCircle />
                {errorMessage}
              </div>
            )}

            <div className="form-group">
              <label htmlFor="name">Name (optional)</label>
              <input
                type="text"
                id="name"
                name="name"
                value={formData.name}
                onChange={handleChange}
                placeholder="Your name"
              />
            </div>

            <div className="form-group">
              <label htmlFor="email">Email (optional)</label>
              <input
                type="email"
                id="email"
                name="email"
                value={formData.email}
                onChange={handleChange}
                placeholder="your@email.com"
              />
              <small style={{ color: 'var(--text-light)', fontSize: '0.875rem' }}>
                Only if you'd like a response
              </small>
            </div>

            <div className="form-group">
              <label htmlFor="type">Type</label>
              <select
                id="type"
                name="type"
                value={formData.type}
                onChange={handleChange}
              >
                <option value="feedback">General Feedback</option>
                <option value="bug">Bug Report</option>
                <option value="feature">Feature Request</option>
                <option value="question">Question</option>
                <option value="other">Other</option>
              </select>
            </div>

            <div className="form-group">
              <label htmlFor="message">Message *</label>
              <textarea
                id="message"
                name="message"
                value={formData.message}
                onChange={handleChange}
                placeholder="Tell us what's on your mind..."
                required
              />
            </div>

            <button
              type="submit"
              className="btn btn-primary form-submit"
              disabled={status === 'loading'}
            >
              {status === 'loading' ? (
                'Sending...'
              ) : (
                <>
                  <FiSend /> Send Feedback
                </>
              )}
            </button>
          </form>

          <div style={{
            textAlign: 'center',
            marginTop: 'var(--spacing-2xl)',
            color: 'var(--text-muted)'
          }}>
            <p>
              You can also reach us on{' '}
              <a
                href="https://github.com/wdvr/footprint/issues"
                target="_blank"
                rel="noopener noreferrer"
              >
                GitHub Issues
              </a>
              {' '}for bug reports and feature requests.
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}

export default FeedbackPage
