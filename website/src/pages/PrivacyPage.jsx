function PrivacyPage() {
  return (
    <div className="legal-page">
      <div className="container">
        <div className="legal-content">
          <h1>Privacy Policy</h1>
          <p className="last-updated">Last updated: January 2026</p>

          <p>
            Your privacy is important to us. This Privacy Policy explains how Footprint ("we", "us",
            or "our") collects, uses, and protects your information when you use our mobile application
            ("App").
          </p>

          <h2>1. Information We Collect</h2>

          <h3>1.1 Information You Provide</h3>
          <ul>
            <li>
              <strong>Apple ID Information:</strong> When you sign in with Apple, we receive a unique
              identifier and, optionally, your name. Apple's privacy features allow you to hide your
              email address.
            </li>
            <li>
              <strong>Travel Data:</strong> Countries, states, and provinces you mark as visited,
              along with any associated metadata.
            </li>
            <li>
              <strong>Feedback:</strong> Information you provide when contacting us through feedback forms.
            </li>
          </ul>

          <h3>1.2 Information Collected Automatically</h3>
          <ul>
            <li>
              <strong>Device Information:</strong> Device type, operating system version, and app version
              for troubleshooting and compatibility purposes.
            </li>
            <li>
              <strong>Location Data:</strong> Only when you explicitly enable location tracking to
              automatically detect visited places. This data is processed locally on your device.
            </li>
            <li>
              <strong>Usage Analytics:</strong> Anonymous, aggregated usage statistics to improve the App.
              No personally identifiable information is included.
            </li>
          </ul>

          <h3>1.3 Information from Third Parties</h3>
          <ul>
            <li>
              <strong>Google Contacts (Optional):</strong> If you choose to import friends from Google,
              we temporarily access your contacts list to find other Footprint users. Contact data is
              not stored on our servers.
            </li>
          </ul>

          <h2>2. How We Use Your Information</h2>
          <p>We use your information to:</p>
          <ul>
            <li>Provide and maintain the App's functionality</li>
            <li>Sync your travel data across your devices</li>
            <li>Enable social features like friend connections</li>
            <li>Respond to your feedback and support requests</li>
            <li>Improve the App based on usage patterns</li>
            <li>Ensure the security and integrity of our services</li>
          </ul>

          <h2>3. Data Storage and Security</h2>

          <h3>3.1 Local Storage</h3>
          <p>
            Your travel data is stored locally on your device using SwiftData. The App works fully
            offline, and local data never leaves your device unless you enable sync.
          </p>

          <h3>3.2 Cloud Storage</h3>
          <p>
            If you enable sync, your data is stored securely on AWS infrastructure using:
          </p>
          <ul>
            <li>Encrypted data transmission (TLS)</li>
            <li>Encrypted data at rest (AES-256)</li>
            <li>Access controls and authentication</li>
          </ul>

          <h2>4. Data Sharing</h2>
          <p>We do not sell your personal information. We may share data only in these circumstances:</p>
          <ul>
            <li>
              <strong>With Your Consent:</strong> When you explicitly share your travel stats or
              connect with friends.
            </li>
            <li>
              <strong>Service Providers:</strong> With trusted third parties who help us operate
              the App (e.g., AWS for hosting), bound by confidentiality agreements.
            </li>
            <li>
              <strong>Legal Requirements:</strong> When required by law or to protect our rights.
            </li>
          </ul>

          <h2>5. Your Rights</h2>
          <p>You have the right to:</p>
          <ul>
            <li>
              <strong>Access:</strong> Request a copy of your personal data
            </li>
            <li>
              <strong>Correction:</strong> Update or correct your information
            </li>
            <li>
              <strong>Deletion:</strong> Request deletion of your account and associated data
            </li>
            <li>
              <strong>Export:</strong> Export your travel data in a portable format
            </li>
            <li>
              <strong>Opt-out:</strong> Disable sync, location tracking, or analytics at any time
            </li>
          </ul>

          <h2>6. Data Retention</h2>
          <p>
            We retain your data for as long as your account is active or as needed to provide services.
            Upon account deletion, we remove your personal data within 30 days, except where retention
            is required by law.
          </p>

          <h2>7. Children's Privacy</h2>
          <p>
            The App is not intended for children under 13. We do not knowingly collect information
            from children under 13. If you believe we have collected such information, please contact us.
          </p>

          <h2>8. International Data Transfers</h2>
          <p>
            Your data may be processed in countries other than your own. We ensure appropriate safeguards
            are in place for such transfers in compliance with applicable laws.
          </p>

          <h2>9. Changes to This Policy</h2>
          <p>
            We may update this Privacy Policy from time to time. We will notify you of significant
            changes through the App. Your continued use after changes constitutes acceptance.
          </p>

          <h2>10. Contact Us</h2>
          <p>
            If you have questions about this Privacy Policy or want to exercise your rights, please
            contact us through our feedback form or via GitHub.
          </p>

          <h2>11. California Residents (CCPA)</h2>
          <p>
            California residents have additional rights under the CCPA, including the right to know
            what personal information is collected and the right to opt-out of the sale of personal
            information (note: we do not sell personal information).
          </p>

          <h2>12. European Residents (GDPR)</h2>
          <p>
            If you are in the European Economic Area, you have additional rights under the GDPR,
            including the right to lodge a complaint with a supervisory authority.
          </p>
        </div>
      </div>
    </div>
  )
}

export default PrivacyPage
