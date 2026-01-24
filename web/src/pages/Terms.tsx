export function Terms() {
  return (
    <div className="min-h-screen bg-gray-50 py-16">
      <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="bg-white rounded-2xl shadow-sm p-8 sm:p-12">
          <h1 className="text-3xl font-bold text-gray-900 mb-8">
            Terms of Service
          </h1>
          <p className="text-gray-600 mb-6">
            Last updated: January 2026
          </p>

          <div className="prose prose-gray max-w-none">
            <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">
              1. Acceptance of Terms
            </h2>
            <p className="text-gray-600 mb-4">
              By downloading, installing, or using the Footprint application ("App"),
              you agree to be bound by these Terms of Service ("Terms"). If you do
              not agree to these Terms, do not use the App.
            </p>

            <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">
              2. Description of Service
            </h2>
            <p className="text-gray-600 mb-4">
              Footprint is a travel tracking application that allows users to mark
              and visualize countries, states, and provinces they have visited on
              an interactive map. The App provides offline functionality with
              optional cloud synchronization.
            </p>

            <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">
              3. User Accounts
            </h2>
            <p className="text-gray-600 mb-4">
              To access certain features of the App, including cloud sync, you may
              need to create an account using Sign in with Apple. You are responsible
              for maintaining the confidentiality of your account and for all
              activities that occur under your account.
            </p>

            <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">
              4. User Data
            </h2>
            <p className="text-gray-600 mb-4">
              You retain all rights to the data you enter into the App. By using
              the cloud sync feature, you grant us a limited license to store and
              process your data solely for the purpose of providing the service
              to you.
            </p>

            <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">
              5. Acceptable Use
            </h2>
            <p className="text-gray-600 mb-4">
              You agree not to:
            </p>
            <ul className="list-disc pl-6 text-gray-600 mb-4">
              <li className="mb-2">Use the App for any unlawful purpose</li>
              <li className="mb-2">Attempt to gain unauthorized access to our systems</li>
              <li className="mb-2">Interfere with or disrupt the App or servers</li>
              <li className="mb-2">Reverse engineer or decompile the App</li>
            </ul>

            <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">
              6. Intellectual Property
            </h2>
            <p className="text-gray-600 mb-4">
              The App and its original content, features, and functionality are
              owned by Footprint and are protected by international copyright,
              trademark, and other intellectual property laws.
            </p>

            <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">
              7. Disclaimer of Warranties
            </h2>
            <p className="text-gray-600 mb-4">
              The App is provided "as is" without warranties of any kind, either
              express or implied. We do not warrant that the App will be
              uninterrupted, error-free, or free of viruses or other harmful
              components.
            </p>

            <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">
              8. Limitation of Liability
            </h2>
            <p className="text-gray-600 mb-4">
              In no event shall Footprint be liable for any indirect, incidental,
              special, consequential, or punitive damages arising out of or
              relating to your use of the App.
            </p>

            <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">
              9. Changes to Terms
            </h2>
            <p className="text-gray-600 mb-4">
              We reserve the right to modify these Terms at any time. We will
              notify users of any material changes through the App or via email.
              Your continued use of the App after such modifications constitutes
              acceptance of the updated Terms.
            </p>

            <h2 className="text-xl font-semibold text-gray-900 mt-8 mb-4">
              10. Contact Us
            </h2>
            <p className="text-gray-600 mb-4">
              If you have any questions about these Terms, please contact us at{' '}
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
