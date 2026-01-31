# SendGrid setup (P2 notifications)

Email is sent via SendGrid. **SendGrid is stored in Google Secret Manager** (secrets `sendgrid-api-key` and `sendgrid-from-email`). The Cloud Functions service account has Secret Manager Secret Accessor on both secrets.

---

## Option A: Secret Manager (recommended)

1. **Enable Secret Manager**  
   In [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → enable **Secret Manager API**.

2. **Create secrets**  
   Security → Secret Manager → Create secret:
   - **sendgrid-api-key**: your SendGrid API key (e.g. `SG.xxx`).
   - **sendgrid-from-email**: sender string, e.g. `Legal AI App <taimur.cems@gmail.com>` or just `taimur.cems@gmail.com`.

3. **Grant access**  
   Ensure the Cloud Functions service account can read secrets:  
   Secret Manager → select each secret → Permissions → Add principal:  
   `legal-ai-app-1203e@appspot.gserviceaccount.com`  
   Role: **Secret Manager Secret Accessor**.

   Or in Cloud Console: IAM → find the App Engine default service account → add role **Secret Manager Secret Accessor** (project-level is enough if secrets are in the same project).

4. **Deploy**  
   `firebase deploy --only functions`

No API key in config or code; functions read from Secret Manager at runtime.

---

## Option B: Firebase config

From project root:

```bash
firebase functions:config:set sendgrid.api_key="YOUR_NEW_SG_KEY" sendgrid.from_email="Legal AI App <taimur.cems@gmail.com>"
firebase deploy --only functions
```

Use a **new** API key (do not reuse one that was ever shared or committed). Verify the sender in SendGrid (Settings → Sender Authentication → Single Sender Verification).

---

## Order of resolution

Functions resolve SendGrid settings in this order:

1. Environment variables: `SENDGRID_API_KEY`, `SENDGRID_FROM_EMAIL`
2. Firebase config: `sendgrid.api_key`, `sendgrid.from_email`
3. Secret Manager: `sendgrid-api-key`, `sendgrid-from-email`

If none are set, email is no-op (logged only; in-app notifications still work).
