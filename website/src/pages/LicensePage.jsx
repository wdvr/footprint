import { FiExternalLink } from 'react-icons/fi'

function LicensePage() {
  return (
    <div className="legal-page">
      <div className="container">
        <div className="legal-content">
          <h1>License</h1>
          <p className="last-updated">GNU Affero General Public License v3.0 (AGPL-3.0)</p>

          <p>
            Footprint is open source software released under the GNU Affero General Public License
            version 3.0. This license was chosen to ensure that the software remains free and open,
            while preventing commercial exploitation without contribution back to the community.
          </p>

          <h2>What This Means</h2>

          <h3>You CAN:</h3>
          <ul>
            <li>Use Footprint for personal or commercial purposes</li>
            <li>View, study, and learn from the source code</li>
            <li>Modify the code to suit your needs</li>
            <li>Distribute your modified version</li>
            <li>Use Footprint as part of a larger project</li>
          </ul>

          <h3>You MUST:</h3>
          <ul>
            <li>Include the original copyright notice and license</li>
            <li>Disclose your source code when you distribute the software</li>
            <li>
              Make your modifications available under the same AGPL-3.0 license if you distribute
              or provide the software as a network service
            </li>
            <li>Document any changes you make to the code</li>
          </ul>

          <h3>You CANNOT:</h3>
          <ul>
            <li>Hold us liable for damages</li>
            <li>Use the Footprint trademark or branding without permission</li>
            <li>Sublicense under different terms</li>
            <li>
              Create a proprietary "closed source" version and sell it without releasing your
              modifications
            </li>
          </ul>

          <h2>Why AGPL-3.0?</h2>
          <p>
            We chose the AGPL-3.0 license because we believe in open source software, but we also
            want to ensure that anyone who improves Footprint shares those improvements with the
            community. The "network clause" in AGPL ensures that even if you run a modified version
            as a service, you must share your changes.
          </p>
          <p>
            This prevents companies from taking our code, making improvements, and offering it as
            a competing service without contributing back. If you want to build on Footprint,
            we welcome your contributions!
          </p>

          <h2>Trademark Notice</h2>
          <p>
            While the source code is open source, the "Footprint" name, logo, and associated
            branding are trademarks and remain proprietary. You may not use these trademarks
            without explicit written permission, except to identify the original project.
          </p>

          <h2>Full License Text</h2>
          <p>
            The complete license text is available in the{' '}
            <a
              href="https://github.com/wdvr/footprint/blob/main/LICENSE"
              target="_blank"
              rel="noopener noreferrer"
            >
              LICENSE file on GitHub <FiExternalLink style={{ verticalAlign: 'middle' }} />
            </a>
          </p>

          <h2>Summary (Not Legal Advice)</h2>
          <div style={{
            background: 'var(--bg)',
            padding: 'var(--spacing-xl)',
            borderRadius: 'var(--radius-lg)',
            marginTop: 'var(--spacing-lg)'
          }}>
            <p style={{ marginBottom: '0' }}>
              <strong>TL;DR:</strong> Footprint is free software. You can use it, modify it, and
              share it. If you distribute it or run it as a service, you must share your source
              code under the same license. You can't close-source it or sell it as proprietary
              software. The branding belongs to us. For the full legal terms, see the complete
              AGPL-3.0 license text.
            </p>
          </div>

          <h2>Third-Party Licenses</h2>
          <p>
            Footprint uses various open source libraries and components. A complete list of
            third-party dependencies and their licenses can be found in the repository.
          </p>
          <ul>
            <li>Swift and SwiftUI - Apple's proprietary license</li>
            <li>Various Swift packages - see Package.swift for details</li>
            <li>Python packages for backend - see requirements.txt</li>
            <li>React and related packages - MIT License</li>
          </ul>

          <h2>Questions?</h2>
          <p>
            If you have questions about the license or want to discuss alternative licensing
            arrangements for commercial use, please contact us through GitHub or our feedback form.
          </p>
        </div>
      </div>
    </div>
  )
}

export default LicensePage
