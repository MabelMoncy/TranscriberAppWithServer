# Deploy to Google Cloud Run

## Prerequisites

1. **Google Cloud Account**: Sign up at https://console.cloud.google.com
2. **Install Google Cloud CLI**: https://cloud.google.com/sdk/docs/install

## Deployment Steps

### 1. Install Google Cloud CLI

**Windows:**
Download and run: https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe

**Verify installation:**
```powershell
gcloud --version
```

### 2. Login to Google Cloud

```powershell
gcloud auth login
```

### 3. Create a New Project (or use existing)

```powershell
# Create project
gcloud projects create transcriber-backend-prod --name="Transcriber Backend"

# Set as active project
gcloud config set project transcriber-backend-prod

# Enable required APIs
gcloud services enable run.googleapis.com
gcloud services enable containerregistry.googleapis.com
```

### 4. Build and Deploy

**From the backend directory:**

```powershell
cd D:\TranscriberAppRepo\backend

# Deploy to Cloud Run (this builds and deploys in one command)
gcloud run deploy transcriberbackend `
  --source . `
  --platform managed `
  --region us-central1 `
  --allow-unauthenticated `
  --set-env-vars GEMINI_API_KEY=AIzaSyD53A3bgIulJQw8iK_lP54vaCZHrncaf-c,APP_SECRET=fd612e7e29c48edd0622c12e9462535ea80bea2ac8f1892fe8e421e5b68a01f8
```

**Note:** Replace the API key and secret with your actual values if different.

### 5. Get Your Backend URL

After deployment completes, you'll see output like:
```
Service URL: https://transcriberbackend-xxxxx-uc.a.run.app
```

Copy this URL!

### 6. Test Your Backend

```powershell
curl https://transcriberbackend-xxxxx-uc.a.run.app
```

Should return: `{"status":"Online","security":"Enabled"}`

### 7. Update Flutter App

Edit `transcriberapp/.env`:
```
SERVER_URL=https://transcriberbackend-xxxxx-uc.a.run.app
API_SECRET=fd612e7e29c48edd0622c12e9462535ea80bea2ac8f1892fe8e421e5b68a01f8
```

---

## Cost Monitoring

Check your usage:
```powershell
gcloud run services describe transcriberbackend --region us-central1 --format="value(status.url)"
```

View logs:
```powershell
gcloud run logs read transcriberbackend --region us-central1
```

---

## Updating Your Backend

When you make changes to code:

```powershell
cd D:\TranscriberAppRepo\backend
git pull
gcloud run deploy transcriberbackend --source . --region us-central1
```

---

## Free Tier Limits

- **2 million requests/month** - FREE
- **360,000 GB-seconds** - FREE
- **180,000 vCPU-seconds** - FREE

**You won't be charged unless you exceed these limits!**

---

## Troubleshooting

### Build fails:
- Check Dockerfile syntax
- Ensure all files are committed to git

### Deployment fails:
- Verify APIs are enabled: `gcloud services list --enabled`
- Check project billing: https://console.cloud.google.com/billing

### App crashes:
- Check logs: `gcloud run logs read transcriberbackend --region us-central1`
