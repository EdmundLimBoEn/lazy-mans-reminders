import type { ReactNode } from 'react'

const CONTACT_EMAIL = 'hello@edmundlim.systems'
const LAST_UPDATED = '26 August 2026'
const SITE_URL = 'https://lmr.edmundlim.systems'

type LegalPageProps = {
  onNavigate: (path: string) => void
}

function LegalShell({
  title,
  children,
  onNavigate,
}: LegalPageProps & { title: string; children: ReactNode }) {
  return (
    <main className="legal-shell">
      <header className="legal-header">
        <a
          className="legal-back"
          href="/"
          onClick={(event) => {
            event.preventDefault()
            onNavigate('/')
          }}
        >
          ← Lazy Man's Reminders
        </a>
        <p className="eyebrow">Legal</p>
        <h1>{title}</h1>
        <p className="legal-updated">Last updated: {LAST_UPDATED}</p>
      </header>

      <aside className="legal-disclaimer" role="note">
        <strong>Not legal advice.</strong> This page is a launch template drafted from the
        product's described practices. It is not a substitute for advice from a qualified
        attorney. Have counsel review and adapt it before relying on it for App Store
        submission, monetization, or public launch.
      </aside>

      <article className="legal-body">{children}</article>

      <nav className="legal-nav" aria-label="Legal pages">
        <a href="/privacy" onClick={(e) => { e.preventDefault(); onNavigate('/privacy') }}>Privacy</a>
        <a href="/terms" onClick={(e) => { e.preventDefault(); onNavigate('/terms') }}>Terms</a>
        <a href="/support" onClick={(e) => { e.preventDefault(); onNavigate('/support') }}>Support</a>
      </nav>
    </main>
  )
}

export function PrivacyPage({ onNavigate }: LegalPageProps) {
  return (
    <LegalShell title="Privacy Policy" onNavigate={onNavigate}>
      <p>
        This Privacy Policy explains how <strong>Edmund Lim</strong> (“we”, “us”, or “operator”),
        operating Lazy Man's Reminders at {SITE_URL} and related iOS apps/widgets
        (the “Service”), handles personal information.
      </p>
      <p>
        Operator contact: <a href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a>
      </p>

      <h2>1. Information we collect</h2>
      <p>Depending on how you use the Service, we may process:</p>
      <ul>
        <li>
          <strong>Account email.</strong> Collected when you sign in with a magic-link / one-time
          password email via Supabase Auth, or when Apple or Google provides an email address as
          part of Sign in with Apple or Google sign-in.
        </li>
        <li>
          <strong>Authentication provider data.</strong> When you use Sign in with Apple or Google,
          those providers authenticate you and may share a stable account identifier, email
          (or Apple’s private relay email), and limited profile metadata with Supabase Auth so we
          can create and maintain your account.
        </li>
        <li>
          <strong>Reminder content.</strong> The text of reminders you create, plus related
          metadata such as sort order, completion status, and timestamps.
        </li>
        <li>
          <strong>Device push tokens.</strong> On iOS, device tokens used to deliver Apple Push
          Notification service (APNs) alerts related to your reminders.
        </li>
        <li>
          <strong>Agent access tokens.</strong> Optional personal tokens you mint so Cursor,
          Claude Code, Codex, or Grok Bot can call your board over MCP. We store only a SHA-256
          hash of the secret. The plaintext token is shown once at creation and is revocable
          from the signed-in web board.
        </li>
        <li>
          <strong>Authentication session data.</strong> Session tokens and related auth state
          needed to keep you signed in securely.
        </li>
        <li>
          <strong>Technical/operational data.</strong> Limited server logs and timestamps
          generated while operating the Service (for example, request timing or error diagnostics
          from our hosting providers).
        </li>
      </ul>
      <p>
        We do <strong>not</strong> currently use advertising SDKs, sell personal data, or run
        third-party product analytics trackers in the Service as described in this policy.
      </p>

      <h2>2. How we use information</h2>
      <ul>
        <li>To create and authenticate your account and sessions.</li>
        <li>To store, sync, and display your reminders across the web app, iOS app, and widget.</li>
        <li>To send push notifications related to reminders you create (when push is enabled).</li>
        <li>To operate, secure, troubleshoot, and improve the Service.</li>
        <li>To respond to support requests and meet legal obligations.</li>
      </ul>

      <h2>3. Legal bases (where applicable)</h2>
      <p>
        If you are in a jurisdiction that requires a legal basis (for example, the EEA/UK), we
        process personal data as needed to perform our contract with you (providing the Service),
        based on our legitimate interests in operating a secure product, and/or with your consent
        where required (for example, certain notification permissions on your device).
      </p>

      <h2>4. How we share information</h2>
      <p>We share information only as needed to run the Service:</p>
      <ul>
        <li>
          <strong>Supabase.</strong> Authentication, Postgres database hosting (including reminder
          content and device tokens), and related backend services. Our Supabase project is
          configured in the Singapore region. Supabase acts as a service provider / processor for
          these operations.
        </li>
        <li>
          <strong>Apple.</strong> If you use Sign in with Apple, the iOS app, App Store purchases,
          or APNs, Apple processes related account, device, payment, and push information under
          Apple's terms and privacy policy. We do not receive your full payment card details from
          Apple for in-app/App Store purchases.
        </li>
        <li>
          <strong>Google.</strong> If you use Google sign-in, Google authenticates you and may
          share account identifiers and email with Supabase Auth under Google's terms and privacy
          policy.
        </li>
        <li>
          <strong>Infrastructure providers.</strong> The web app may be hosted on Cloudflare Pages
          or similar static hosting. Those providers may process IP addresses and request metadata
          as part of delivering the site.
        </li>
        <li>
          <strong>Legal and safety.</strong> We may disclose information if required by law or to
          protect rights, safety, and the integrity of the Service.
        </li>
      </ul>
      <p>We do not sell your personal information.</p>

      <h2>5. Cookies and local storage</h2>
      <p>
        The web app uses browser storage (such as local storage) as needed for authentication
        session persistence with Supabase Auth. We do not use advertising cookies. Essential
        storage required to keep you signed in may be used without a separate cookie banner where
        permitted by law.
      </p>

      <h2>6. Retention</h2>
      <ul>
        <li>
          Account, reminder, and device-token data are retained while your account remains active
          and as needed to provide the Service.
        </li>
        <li>
          If you ask us to delete your account or data, we will delete or anonymize personal data
          we control within a reasonable period, except where we must retain information for
          security, dispute resolution, backups for a limited time, or legal compliance.
        </li>
        <li>
          Invalid or unused push tokens may be removed as part of normal APNs delivery handling.
        </li>
      </ul>

      <h2>7. International transfers</h2>
      <p>
        Primary application data is hosted with Supabase in Singapore. Providers such as Apple and
        Cloudflare may process data in other countries. Where required, we rely on appropriate
        safeguards offered by those providers (such as standard contractual clauses) and your
        use of the Service.
      </p>

      <h2>8. Security</h2>
      <p>
        We use industry-standard measures appropriate to a small consumer app, including encrypted
        transport (HTTPS), authenticated access controls, and database row-level security policies
        in Supabase. No method of transmission or storage is perfectly secure.
      </p>

      <h2>9. Children's privacy</h2>
      <p>
        The Service is not directed to children under 13 (or the minimum age required in your
        country). We do not knowingly collect personal information from children. If you believe a
        child has provided personal information, contact us and we will take appropriate steps to
        delete it.
      </p>

      <h2>10. Your rights</h2>
      <p>
        Depending on your location, you may have rights to access, correct, delete, or export your
        personal data, or to object to / restrict certain processing. To exercise these rights,
        email <a href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a> from the address associated
        with your account. You may also delete individual reminders in the product.
      </p>
      <p>
        You can delete your account in the product: use <em>Delete account</em> on the signed-in
        web board or in the iOS app. That removes your reminders, device push tokens, agent
        access tokens, and auth account. You may also email <a href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a> from
        the address associated with your account if you need help. We will verify email requests
        and delete account data we control, subject to the retention exceptions above.
      </p>

      <h2>11. Paid features and Apple</h2>
      <p>
        If a paid iOS version or in-app purchase is offered (for example, a planned one-time App
        Store purchase), Apple processes the payment. Purchase records are also subject to Apple's
        privacy practices. We only use purchase/entitlement signals as needed to unlock paid
        features.
      </p>

      <h2>12. Changes</h2>
      <p>
        We may update this Privacy Policy from time to time. The “Last updated” date at the top
        will change when we do. Continued use of the Service after an update means you accept the
        revised policy, except where applicable law requires additional notice or consent.
      </p>

      <h2>13. Contact</h2>
      <p>
        Questions about privacy: <a href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a><br />
        Operator: Edmund Lim / edmundlim.systems<br />
        Service: Lazy Man's Reminders ({SITE_URL})
      </p>
    </LegalShell>
  )
}

export function TermsPage({ onNavigate }: LegalPageProps) {
  return (
    <LegalShell title="Terms of Use" onNavigate={onNavigate}>
      <p>
        These Terms of Use (“Terms”) govern access to and use of Lazy Man's Reminders, including
        the website at {SITE_URL}, the iOS application, and related WidgetKit experiences
        (collectively, the “Service”), operated by <strong>Edmund Lim</strong> (“we”, “us”).
      </p>
      <p>
        By creating an account or using the Service, you agree to these Terms. If you do not
        agree, do not use the Service.
      </p>
      <aside className="legal-callout" role="note">
        <strong>Governing-law note.</strong> These Terms currently designate Singapore law as a
        working default. Have a lawyer confirm the correct governing law, venue, and entity
        naming before monetized launch.
      </aside>

      <h2>1. The Service</h2>
      <p>
        Lazy Man's Reminders is a personal reminder board that syncs reminder text across web and
        iOS experiences and may deliver push notifications and lock-screen widget updates. Features
        may change, be limited, or be discontinued as the product evolves.
      </p>

      <h2>2. Eligibility and accounts</h2>
      <ul>
        <li>You must be able to form a binding contract in your jurisdiction.</li>
        <li>You must provide a valid email address (or use Sign in with Apple / Google) and keep access to your sign-in method secure.</li>
        <li>
          You are responsible for activity under your account. Contact us promptly if you suspect
          unauthorized access.
        </li>
        <li>One person should use one account; do not share sign-in links or credentials with others.</li>
      </ul>

      <h2>3. Acceptable use</h2>
      <p>You agree not to:</p>
      <ul>
        <li>Use the Service for unlawful, harmful, or abusive purposes.</li>
        <li>Attempt to access other users' data or bypass security or rate limits.</li>
        <li>Reverse engineer, scrape, or overload the Service except as allowed by law.</li>
        <li>Upload malware or content that infringes others' rights.</li>
        <li>Misrepresent your identity or affiliation when contacting support.</li>
      </ul>
      <p>
        Reminder content is user-generated. You remain responsible for what you store. The Service
        is intended for personal reminder use, not as a system of record for regulated, medical,
        or emergency communications.
      </p>

      <h2>4. Intellectual property</h2>
      <p>
        The Service's branding, design, software, and documentation are owned by us or our
        licensors. You retain ownership of the reminder content you create. You grant us a limited
        license to host, transmit, and display that content solely to operate the Service for you.
      </p>

      <h2>5. Paid App Store purchases</h2>
      <p>
        If the iOS app is offered as a paid download or includes a one-time purchase (planned
        price: US $1.50 / S$2.00, subject to change in the App Store), payment is processed by
        Apple, not directly by us.
      </p>
      <ul>
        <li>Pricing, taxes, billing, refunds, and cancellations are handled under Apple's App Store
          terms and policies.</li>
        <li>
          To the extent a purchase dispute or refund request relates to Apple billing, contact
          Apple. We can assist with Service access issues after purchase verification.
        </li>
        <li>
          Paid features, if any, are licensed to you for personal, non-transferable use on Apple
          platforms under these Terms and Apple's terms.
        </li>
      </ul>

      <h2>6. Third-party services</h2>
      <p>
        The Service depends on third parties including Supabase (auth and database) and Apple
        (App Store distribution, payments, and APNs). Their availability and policies affect the
        Service. We are not responsible for outages or changes outside our reasonable control.
      </p>

      <h2>7. Disclaimer of warranties</h2>
      <p>
        THE SERVICE IS PROVIDED “AS IS” AND “AS AVAILABLE.” TO THE MAXIMUM EXTENT PERMITTED BY
        LAW, WE DISCLAIM ALL WARRANTIES, EXPRESS OR IMPLIED, INCLUDING MERCHANTABILITY, FITNESS
        FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT. We do not warrant that reminders or
        notifications will be delivered without delay or interruption, or that the Service will be
        error-free.
      </p>

      <h2>8. Limitation of liability</h2>
      <p>
        TO THE MAXIMUM EXTENT PERMITTED BY LAW, WE WILL NOT BE LIABLE FOR INDIRECT, INCIDENTAL,
        SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, OR FOR LOST PROFITS, DATA, OR GOODWILL,
        ARISING FROM YOUR USE OF THE SERVICE. OUR TOTAL LIABILITY FOR ANY CLAIM RELATING TO THE
        SERVICE WILL NOT EXCEED THE GREATER OF (A) THE AMOUNT YOU PAID US FOR THE SERVICE IN THE
        12 MONTHS BEFORE THE CLAIM OR (B) US $30.
      </p>
      <p>
        Some jurisdictions do not allow certain limitations; in those places, our liability is
        limited to the fullest extent allowed.
      </p>

      <h2>9. Termination</h2>
      <p>
        You may stop using the Service at any time. You may delete your account in the product
        (web board or iOS app) or by contacting support. Deletion removes your reminders, device
        registrations, and sign-in. We may suspend or terminate access if you violate these Terms,
        if required by law, or if we discontinue the Service. Provisions that by nature should
        survive (including IP, disclaimers, limitations, and governing law) will survive
        termination.
      </p>

      <h2>10. Changes to the Service or Terms</h2>
      <p>
        We may modify the Service or these Terms. Material changes will be reflected by updating
        the “Last updated” date and, where appropriate, posting the revised Terms on the site.
        Continued use after changes become effective constitutes acceptance, except where
        applicable law requires otherwise.
      </p>

      <h2>11. Governing law</h2>
      <p>
        These Terms are governed by the laws of <strong>Singapore</strong>, without regard to
        conflict-of-law rules. Courts in Singapore shall have exclusive jurisdiction over disputes,
        except where mandatory consumer protections in your country require otherwise.
      </p>

      <h2>12. Contact</h2>
      <p>
        Questions about these Terms: <a href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a><br />
        Operator: Edmund Lim / edmundlim.systems
      </p>
    </LegalShell>
  )
}

export function SupportPage({ onNavigate }: LegalPageProps) {
  return (
    <LegalShell title="Support" onNavigate={onNavigate}>
      <p>
        Need help with Lazy Man's Reminders? Email{' '}
        <a href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a> and include:
      </p>
      <ul>
        <li>The email address on your account</li>
        <li>Whether you're using the web app, iOS app, and/or lock-screen widget</li>
        <li>What you expected vs. what happened</li>
        <li>For purchase issues: your App Store transaction details (do not send card numbers)</li>
      </ul>

      <h2>Common topics</h2>
      <ul>
        <li>
          <strong>Sign-in.</strong> Magic links expire; request a new link from the sign-in screen
          if yours no longer works. You can also use Sign in with Apple or Google where offered.
        </li>
        <li>
          <strong>Widget / push.</strong> Open the iOS app after signing in, keep notifications
          enabled if you want alerts, and add the widget from the lock-screen gallery.
        </li>
        <li>
          <strong>Account or data deletion.</strong> Use <em>Delete account</em> on the signed-in
          web board or in the iOS app (More menu), or email us from your account address if you
          need help completing deletion.
        </li>
        <li>
          <strong>Refunds.</strong> App Store billing and refunds are handled by Apple under
          Apple's policies.
        </li>
      </ul>

      <h2>App Store review</h2>
      <p>
        Reviewers and users can reach the operator at{' '}
        <a href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a>. Privacy Policy:{' '}
        <a href="/privacy" onClick={(e) => { e.preventDefault(); onNavigate('/privacy') }}>
          {SITE_URL}/privacy
        </a>
        . Terms:{' '}
        <a href="/terms" onClick={(e) => { e.preventDefault(); onNavigate('/terms') }}>
          {SITE_URL}/terms
        </a>
        .
      </p>
    </LegalShell>
  )
}

export function LegalFooterLinks({ onNavigate }: LegalPageProps) {
  return (
    <nav className="legal-footer-links" aria-label="Legal and support">
      <a href="/privacy" onClick={(e) => { e.preventDefault(); onNavigate('/privacy') }}>Privacy</a>
      <span aria-hidden="true">·</span>
      <a href="/terms" onClick={(e) => { e.preventDefault(); onNavigate('/terms') }}>Terms</a>
      <span aria-hidden="true">·</span>
      <a href="/support" onClick={(e) => { e.preventDefault(); onNavigate('/support') }}>Support</a>
    </nav>
  )
}

export { CONTACT_EMAIL }
