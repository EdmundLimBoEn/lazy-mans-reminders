import type { ReactNode } from 'react'

const CONTACT_EMAIL = 'hello@edmundlim.systems'
const LAST_UPDATED = '26 August 2026'
const SITE_URL = 'https://lmr.edmundlim.systems'
const PDPC_URL = 'https://www.pdpc.gov.sg'

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
        This Privacy Policy describes how <strong>Edmund Lim</strong> (“we”, “us”, or “operator”),
        a sole operator in Singapore, handles personal information for Lazy Man's Reminders at{' '}
        {SITE_URL}, the iOS app, lock-screen widgets, Live Activities, and the agent connector
        (together, the “Service”).
      </p>
      <p>
        Operator contact: <a href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a>
      </p>
      <p>
        We are the data controller (and, under Singapore’s PDPA, the organisation) for personal
        data collected through the Service.
      </p>

      <h2>1. Information we collect</h2>
      <p>Depending on how you use the Service, we process:</p>
      <ul>
        <li>
          <strong>Account email.</strong> Collected when you sign in with a magic-link email via
          Supabase Auth, or when Apple or Google provides an email (including Apple’s Hide My Email
          relay) as part of sign-in.
        </li>
        <li>
          <strong>Authentication provider data.</strong> A stable account identifier and limited
          profile metadata from Apple or Google, stored by Supabase Auth so we can keep your
          account.
        </li>
        <li>
          <strong>Reminder content.</strong> The text you or an authorized agent create, plus sort
          order, completion status, and timestamps.
        </li>
        <li>
          <strong>Lock Screen preferences.</strong> How many reminder lines fit on your iPhone Live
          Activity, measured on the device and stored so the web board uses the same capacity.
        </li>
        <li>
          <strong>Device push tokens.</strong> On iOS, tokens used to send Apple Push Notification
          service (APNs) alerts when a reminder is added.
        </li>
        <li>
          <strong>Agent access.</strong> OAuth grants when you tap Allow for a client such as Grok,
          Claude, Cursor, or Codex. Optional personal keys you mint are stored as a SHA-256 hash.
          The plaintext key is shown once and is revocable from the signed-in web board. We do not
          store the plaintext after that screen.
        </li>
        <li>
          <strong>Session data.</strong> Tokens in browser storage or the iOS app needed to keep
          you signed in.
        </li>
        <li>
          <strong>Operational logs.</strong> Limited request timing and error diagnostics from our
          hosting providers.
        </li>
      </ul>
      <p>
        We do not use advertising SDKs, sell personal data, run third-party product analytics, or
        track you across other companies’ apps or websites.
      </p>

      <h2>2. How we use information</h2>
      <ul>
        <li>Create and authenticate your account and sessions.</li>
        <li>Store, sync, and display reminders on the web board, iOS app, widget, and Live Activity.</li>
        <li>Send push notifications for new reminders when you have allowed notifications.</li>
        <li>Let an agent you authorized read, add, and complete reminders on your board.</li>
        <li>Match web-board capacity to your iPhone Lock Screen.</li>
        <li>Operate, secure, and troubleshoot the Service, and respond to support requests.</li>
        <li>Meet legal obligations, including PDPA and similar laws.</li>
      </ul>
      <p>
        Reminder text you add can appear on your iPhone lock screen (widget and Live Activity).
        Anyone who can see the phone can see those lines. That is how the product works. Do not
        store secrets or highly sensitive notes if that visibility is a problem.
      </p>

      <h2>3. Legal bases and PDPA purposes</h2>
      <p>
        We collect and use this data to provide the Service you asked for (contract / purpose
        limitation under PDPA). Where a law such as the GDPR requires a legal basis, we rely on
        performance of a contract, legitimate interests in running a secure product, and consent
        where a platform requires it (for example, notification permission on iOS).
      </p>
      <p>
        We do not use your data for automated decision-making that produces legal or similarly
        significant effects.
      </p>

      <h2>4. Subprocessors and sharing</h2>
      <p>We share information only as needed to run the Service:</p>
      <ul>
        <li>
          <strong>Supabase</strong> (Singapore region). Authentication, Postgres, Realtime, and
          Edge Functions. Processor for account, reminders, tokens, and prefs.{' '}
          <a href="https://supabase.com/privacy">Supabase privacy</a>
        </li>
        <li>
          <strong>Cloudflare.</strong> Pages hosting for the website and a Worker for the agent
          MCP/OAuth connector. May process IP addresses and request metadata.{' '}
          <a href="https://www.cloudflare.com/privacypolicy/">Cloudflare privacy</a>
        </li>
        <li>
          <strong>Resend.</strong> Delivery of magic-link email through our auth domain.{' '}
          <a href="https://resend.com/legal/privacy-policy">Resend privacy</a>
        </li>
        <li>
          <strong>Apple.</strong> Sign in with Apple, App Store distribution, APNs, and widgets.
          Apple’s terms and privacy policy apply.{' '}
          <a href="https://www.apple.com/legal/privacy/">Apple privacy</a>
        </li>
        <li>
          <strong>Google.</strong> Google sign-in when you choose it.{' '}
          <a href="https://policies.google.com/privacy">Google privacy</a>
        </li>
        <li>
          <strong>Agents you authorize.</strong> If you Allow an MCP client, that client can read
          and change reminder text on your board until you revoke access. Those tools are not our
          subprocessors. They are acting with your permission. Their own policies apply to what
          they retain.
        </li>
        <li>
          <strong>Legal and safety.</strong> We may disclose information if required by law or to
          protect rights, safety, and the integrity of the Service.
        </li>
      </ul>
      <p>
        We do not sell personal information. We do not share it for cross-context behavioural
        advertising.
      </p>

      <h2>5. Cookies and local storage</h2>
      <p>
        The web app uses browser local storage (and similar) only to keep your Supabase Auth
        session. There are no advertising cookies and no optional analytics cookies. We do not
        show a cookie banner because this storage is required to sign you in. You can clear it
        by signing out or clearing site data in your browser.
      </p>

      <h2>6. Retention</h2>
      <ul>
        <li>
          Account, active reminders, device tokens, lock-screen prefs, and agent grants are kept
          while the account exists.
        </li>
        <li>
          Completed reminders are deleted automatically after 7 days when a client opens the
          board (and, if configured, by a daily database job).
        </li>
        <li>
          Invalid APNs tokens may be removed during normal push delivery.
        </li>
        <li>
          If you delete your account, we delete personal data we control. Backups and logs may
          lag for a short period. We keep information only if we must for security, disputes, or
          law.
        </li>
      </ul>

      <h2>7. International transfers</h2>
      <p>
        Application data sits with Supabase in Singapore. Apple, Google, Cloudflare, and Resend
        may process data in other countries. Where a transfer law applies, we rely on those
        providers’ published safeguards (such as standard contractual clauses) and on the fact
        that you chose this Service.
      </p>

      <h2>8. Security</h2>
      <p>
        We use HTTPS, authenticated access, and Supabase row-level security so one user cannot
        read another user’s board. Personal agent keys are stored hashed. No method of
        transmission or storage is perfectly secure. Report a vulnerability to{' '}
        <a href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a>. If a notifiable data breach
        occurs, we will notify the PDPC and affected individuals as Singapore law requires.
      </p>

      <h2>9. Children's privacy</h2>
      <p>
        The Service is not directed to children under 13, or under the digital consent age in
        your country if that age is higher. We do not knowingly collect personal information from
        children. If you believe a child has created an account, email us and we will delete it.
      </p>

      <h2>10. Your rights</h2>
      <p>
        Depending on where you live, you may have rights to access, correct, delete, or export
        your personal data, to withdraw consent, and to object to or restrict some processing.
        Singapore PDPA also covers access and correction. You can:
      </p>
      <ul>
        <li>Edit or delete individual reminders in the product.</li>
        <li>
          Download a JSON copy of your account, reminders, lock-screen preference, and agent-key
          names from the signed-in web board (<em>Download my data</em>).
        </li>
        <li>
          Delete the account in the product (web board or iOS More menu). That removes reminders,
          device tokens, lock-screen prefs, agent keys, OAuth grants we store, and the auth user.
        </li>
        <li>
          Email <a href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a> from the address on the
          account if you need help. We will verify the request.
        </li>
      </ul>
      <p>
        You may lodge a complaint with the Personal Data Protection Commission of Singapore at{' '}
        <a href={PDPC_URL}>{PDPC_URL}</a>. If you are in the EEA, UK, or another region with a
        supervisory authority, you may also complain there.
      </p>
      <p>
        California residents. We do not sell or share personal information as those terms are
        used in the CCPA/CPRA. We do not use or disclose sensitive personal information for
        purposes that require a right to limit.
      </p>

      <h2>11. Pricing</h2>
      <p>
        Lazy Man's Reminders is free on the App Store and on the web. There are no in-app
        purchases or subscriptions.
      </p>

      <h2>12. Changes</h2>
      <p>
        We may update this Privacy Policy. The “Last updated” date at the top will change when
        we do. For material changes we will post the new policy on this page. Continued use
        after an update means you accept the revised policy, except where law requires extra
        notice or consent.
      </p>

      <h2>13. Contact</h2>
      <p>
        Privacy questions and data requests:{' '}
        <a href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a><br />
        Operator: Edmund Lim, Singapore / edmundlim.systems<br />
        Service: Lazy Man's Reminders ({SITE_URL})
      </p>
    </LegalShell>
  )
}

export function TermsPage({ onNavigate }: LegalPageProps) {
  return (
    <LegalShell title="Terms of Use" onNavigate={onNavigate}>
      <p>
        These Terms of Use (“Terms”) govern access to Lazy Man's Reminders, including the
        website at {SITE_URL}, the iOS application, widgets, Live Activities, and the agent
        connector (collectively, the “Service”), operated by <strong>Edmund Lim</strong> in
        Singapore (“we”, “us”).
      </p>
      <p>
        By creating an account or using the Service, you agree to these Terms. If you do not
        agree, do not use the Service.
      </p>

      <h2>1. The Service</h2>
      <p>
        Lazy Man's Reminders is a personal reminder board. It syncs short reminder lines across
        web and iOS and may show them on your lock screen and send push notifications. Features
        may change or stop as the product evolves. The Service is not a medical device, not an
        alarm for emergencies, and not a system of record for regulated records.
      </p>

      <h2>2. Eligibility and accounts</h2>
      <ul>
        <li>You must be able to form a binding contract in your jurisdiction.</li>
        <li>
          You must keep access to your email or Sign in with Apple / Google secure. You are
          responsible for activity under your account, including actions taken by agents you
          authorize.
        </li>
        <li>Do not share sign-in links, session tokens, or personal agent keys.</li>
        <li>Contact us promptly if you suspect unauthorized access.</li>
      </ul>

      <h2>3. Acceptable use</h2>
      <p>You agree not to:</p>
      <ul>
        <li>Use the Service for unlawful, harmful, or abusive purposes.</li>
        <li>Attempt to access other users' data or bypass security or rate limits.</li>
        <li>Reverse engineer, scrape, or overload the Service except as allowed by law.</li>
        <li>Upload malware or content that infringes others' rights.</li>
        <li>Misrepresent your identity when contacting support.</li>
        <li>
          Point an agent at the Service in a way that violates these Terms. If an agent adds a
          reminder, you are the one who added it.
        </li>
      </ul>
      <p>
        Reminder content is yours. You remain responsible for what you store, including text an
        authorized agent writes.
      </p>

      <h2>4. Agent access</h2>
      <p>
        You may connect a client (for example Grok, Claude, Cursor, or Codex) through OAuth or a
        personal key. Allowing a client lets it read, add, and complete reminders until you
        revoke it on the web board or delete your account. Revoke access you no longer want.
        We are not responsible for what a third-party agent does with reminder text after you
        share it with that agent.
      </p>

      <h2>5. Intellectual property</h2>
      <p>
        The Service's branding, design, software, and documentation are owned by us or our
        licensors. You retain ownership of the reminder content you create. You grant us a
        limited license to host, transmit, and display that content solely to operate the
        Service for you.
      </p>

      <h2>6. Price</h2>
      <p>
        The Service is free. There is no download fee and no in-app purchase or subscription.
        Apple still distributes the iOS app under Apple's terms.
      </p>

      <h2>7. Third-party services</h2>
      <p>
        The Service depends on third parties including Supabase, Cloudflare, Resend, Apple, and
        Google. Their availability and policies affect the Service. We are not responsible for
        outages or changes outside our reasonable control.
      </p>

      <h2>8. Disclaimer of warranties</h2>
      <p>
        THE SERVICE IS PROVIDED “AS IS” AND “AS AVAILABLE.” TO THE MAXIMUM EXTENT PERMITTED BY
        LAW, WE DISCLAIM ALL WARRANTIES, EXPRESS OR IMPLIED, INCLUDING MERCHANTABILITY, FITNESS
        FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT. We do not warrant that reminders or
        notifications will arrive without delay or interruption, or that the Service will be
        error-free.
      </p>

      <h2>9. Limitation of liability</h2>
      <p>
        TO THE MAXIMUM EXTENT PERMITTED BY LAW, WE WILL NOT BE LIABLE FOR INDIRECT, INCIDENTAL,
        SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, OR FOR LOST PROFITS, DATA, OR GOODWILL,
        ARISING FROM YOUR USE OF THE SERVICE. OUR TOTAL LIABILITY FOR ANY CLAIM RELATING TO THE
        SERVICE WILL NOT EXCEED THE GREATER OF (A) THE AMOUNT YOU PAID US FOR THE SERVICE IN THE
        12 MONTHS BEFORE THE CLAIM OR (B) US $30. Because the Service is free, that amount is
        ordinarily US $30.
      </p>
      <p>
        Some jurisdictions do not allow certain limitations. In those places, our liability is
        limited to the fullest extent allowed. Nothing in these Terms excludes liability that
        cannot be excluded under Singapore law.
      </p>

      <h2>10. Termination</h2>
      <p>
        You may stop using the Service at any time. You may delete your account in the product
        (web board or iOS app) or by contacting support. Deletion removes your reminders, device
        registrations, lock-screen prefs, agent access, and sign-in. We may suspend or terminate
        access if you violate these Terms, if required by law, or if we discontinue the Service.
        Provisions that by nature should survive (including IP, disclaimers, limitations, and
        governing law) will survive termination.
      </p>

      <h2>11. Changes to the Service or Terms</h2>
      <p>
        We may modify the Service or these Terms. Material changes will be reflected by updating
        the “Last updated” date and posting the revised Terms on this page. Continued use after
        changes become effective constitutes acceptance, except where applicable law requires
        otherwise.
      </p>

      <h2>12. Governing law</h2>
      <p>
        These Terms are governed by the laws of <strong>Singapore</strong>, without regard to
        conflict-of-law rules. Courts in Singapore have exclusive jurisdiction over disputes,
        except where mandatory consumer protections in your country require otherwise.
      </p>

      <h2>13. Contact</h2>
      <p>
        Questions about these Terms: <a href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a><br />
        Operator: Edmund Lim, Singapore / edmundlim.systems
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
        <li>Whether you're using the web app, iOS app, lock-screen widget, or an agent</li>
        <li>What you expected vs. what happened</li>
      </ul>
      <p>
        There is no guaranteed response time. This is a small free product. We still read the
        inbox.
      </p>

      <h2>Common topics</h2>
      <ul>
        <li>
          <strong>Sign-in.</strong> Magic links expire. Request a new link from the sign-in
          screen. You can also use Sign in with Apple or Google.
        </li>
        <li>
          <strong>Widget / push.</strong> Open the iOS app after signing in, allow
          notifications if you want alerts, and add the widget from the lock-screen gallery.
        </li>
        <li>
          <strong>Download your data.</strong> On the signed-in web board, use{' '}
          <em>Download my data</em>. That saves a JSON file with your email, reminders,
          lock-screen line budget, and agent-key names (not plaintext keys).
        </li>
        <li>
          <strong>Revoke an agent.</strong> On the signed-in web board, open Advanced under
          Agent access and revoke the key, or disconnect the OAuth client and delete the
          account if you want a full wipe.
        </li>
        <li>
          <strong>Account deletion.</strong> Use <em>Delete account</em> on the signed-in web
          board or in the iOS app (More menu). Or email us from your account address if the
          in-product path fails.
        </li>
        <li>
          <strong>Price.</strong> The app and web board are free. There are no in-app purchases.
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
