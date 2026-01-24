export function Privacy() {
  return (
    <div className="min-h-screen bg-gray-50 py-16">
      <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="bg-white rounded-2xl shadow-sm p-8 sm:p-12">
          <h1 className="text-3xl font-bold text-gray-900 mb-8">
            Privacy Policy
          </h1>
          <p className="text-gray-600 mb-6">
            Last updated: January 2026
          </p>

          <div className="prose prose-gray max-w-none">
            <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">
              1. Introduction
            </h2>
            <p className="text-gray-600 mb-4">
              Footprint ("we", "our", or "us") is committed to protecting your
              privacy. This Privacy Policy explains how we collect, use, and
              safeguard your information when you use our mobile application.
            </p>

            <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">
              2. Information We Collect
            </h2>
            <p className="text-gray-600 mb-4">
              We collect minimal information necessary to provide our service:
            </p>
            <ul className="list-disc pl-6 text-gray-600 mb-4">
              <li className="mb-2">
                <strong>Account Information:</strong> When you sign in with Apple,
                we receive a unique identifier and optionally your email address
                (if you choose to share it).
              </li>
              <li className="mb-2">
                <strong>Travel Data:</strong> The countries, states, and provinces
                you mark as visited within the App.
              </li>
              <li className="mb-2">
                <strong>Device Information:</strong> Basic device information for
                app functionality and troubleshooting.
              </li>
            </ul>

            <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">
              3. How We Use Your Information
            </h2>
            <p className="text-gray-600 mb-4">
              We use your information solely to:
            </p>
            <ul className="list-disc pl-6 text-gray-600 mb-4">
              <li className="mb-2">Provide and maintain the App</li>
              <li className="mb-2">Sync your travel data across your devices</li>
              <li className="mb-2">Improve and optimize the App</li>
              <li className="mb-2">Respond to your support requests</li>
            </ul>

            <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">
              4. Data Storage and Security
            </h2>
            <p className="text-gray-600 mb-4">
              Your travel data is stored locally on your device and, if you enable
              cloud sync, securely in our cloud infrastructure. We use
              industry-standard encryption and security measures to protect your
              data.
            </p>

            <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">
              5. Data Sharing
            </h2>
            <p className="text-gray-600 mb-4">
              We do not sell, trade, or otherwise transfer your personal information
              to third parties. We may share information only in the following
              circumstances:
            </p>
            <ul className="list-disc pl-6 text-gray-600 mb-4">
              <li className="mb-2">With your explicit consent</li>
              <li className="mb-2">To comply with legal obligations</li>
              <li className="mb-2">
                To protect our rights, privacy, safety, or property
              </li>
            </ul>

            <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">
              6. Your Rights
            </h2>
            <p className="text-gray-600 mb-4">
              You have the right to:
            </p>
            <ul className="list-disc pl-6 text-gray-600 mb-4">
              <li className="mb-2">Access your personal data</li>
              <li className="mb-2">Correct inaccurate data</li>
              <li className="mb-2">Delete your data</li>
              <li className="mb-2">Export your data</li>
              <li className="mb-2">Withdraw consent for data processing</li>
            </ul>

            <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">
              7. Data Retention
            </h2>
            <p className="text-gray-600 mb-4">
              We retain your data for as long as your account is active. If you
              delete your account, we will delete your personal data within 30
              days, except where we are required to retain it for legal purposes.
            </p>

            <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">
              8. Children's Privacy
            </h2>
            <p className="text-gray-600 mb-4">
              The App is not intended for children under 13 years of age. We do
              not knowingly collect personal information from children under 13.
            </p>

            <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">
              9. Changes to This Policy
            </h2>
            <p className="text-gray-600 mb-4">
              We may update this Privacy Policy from time to time. We will notify
              you of any changes by posting the new Privacy Policy in the App and
              updating the "Last updated" date.
            </p>

            <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">
              10. Contact Us
            </h2>
            <p className="text-gray-600 mb-4">
              If you have any questions about this Privacy Policy or our data
              practices, please contact us at{' '}
              <a
                href="mailto:support@footprint.app"
                className="text-emerald-600 hover:text-emerald-700"
              >
                support@footprint.app
              </a>
              .
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
