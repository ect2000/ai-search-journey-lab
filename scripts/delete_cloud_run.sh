#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Full GCP Cleanup Script for AI Search Journey Lab
#
# Deletes repo-specific billable resources:
#   - Cloud Run service
#   - Artifact Registry repository and all container images
#   - BigQuery V3 dataset
#   - Cloud Build storage bucket
#
# Preserves:
#   - GCP project
#   - Secret Manager secrets
#   - Gemini API key secret
#   - Google Maps API key secret
#   - Service accounts
#   - IAM bindings
#   - Enabled APIs
#
# Usage:
#   ./scripts/delete_cloud_run.sh
#   ./scripts/delete_cloud_run.sh --yes
# ==============================================================================

PROJECT_ID="${PROJECT_ID:-ai-search-journey-lab}"
REGION="${REGION:-us-central1}"

SERVICE="${SERVICE:-ai-search-journey-lab}"
REPOSITORY="${REPOSITORY:-ai-search-journey}"
BIGQUERY_DATASET="${BIGQUERY_DATASET:-ai_search_journey_v3}"
CLOUDBUILD_BUCKET="${CLOUDBUILD_BUCKET:-${PROJECT_ID}_cloudbuild}"

AUTO_CONFIRM=false

if [[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]]; then
  AUTO_CONFIRM=true
fi


# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

section() {
  echo ""
  echo "----------------------------------------------------------------------"
  echo "$1"
  echo "----------------------------------------------------------------------"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}


# ------------------------------------------------------------------------------
# Header
# ------------------------------------------------------------------------------

echo "======================================================================"
echo "⚠️  AI Search Journey Lab — Full GCP Resource Cleanup"
echo "======================================================================"
echo "Project:              ${PROJECT_ID}"
echo "Region:               ${REGION}"
echo "Cloud Run Service:    ${SERVICE}"
echo "Artifact Repository:  ${REPOSITORY}"
echo "BigQuery Dataset:     ${BIGQUERY_DATASET}"
echo "Cloud Build Bucket:   gs://${CLOUDBUILD_BUCKET}"
echo "======================================================================"
echo ""

echo "This script WILL DELETE:"
echo "  1. Cloud Run service"
echo "  2. Artifact Registry repository and all container images"
echo "  3. BigQuery dataset and all tables"
echo "  4. Cloud Build storage bucket and its contents"
echo ""

echo "This script WILL PRESERVE:"
echo "  - GCP project '${PROJECT_ID}'"
echo "  - Secret Manager secrets and versions"
echo "  - gemini-api-key"
echo "  - google-maps-api-key"
echo "  - Service Accounts"
echo "  - IAM permissions"
echo "  - Enabled GCP APIs"
echo "  - Billing configuration"
echo ""


# ------------------------------------------------------------------------------
# Verify CLI tools
# ------------------------------------------------------------------------------

command_exists gcloud || {
  echo "❌ ERROR: gcloud CLI is required."
  exit 1
}

command_exists bq || {
  echo "❌ ERROR: bq CLI is required."
  exit 1
}


# ------------------------------------------------------------------------------
# Confirmation
# ------------------------------------------------------------------------------

if [[ "${AUTO_CONFIRM}" != "true" ]]; then
  read -r -p "Are you sure you want to permanently remove these resources? (y/N): " CONFIRMATION

  if [[ ! "${CONFIRMATION}" =~ ^[Yy]$ ]]; then
    echo "❌ Cleanup aborted."
    exit 0
  fi
fi


# ------------------------------------------------------------------------------
# Set project
# ------------------------------------------------------------------------------

section "Setting active GCP project"

gcloud config set project "${PROJECT_ID}" --quiet

ACTIVE_PROJECT="$(gcloud config get-value project 2>/dev/null)"

if [[ "${ACTIVE_PROJECT}" != "${PROJECT_ID}" ]]; then
  echo "❌ ERROR: Active project is '${ACTIVE_PROJECT}', expected '${PROJECT_ID}'."
  exit 1
fi

echo "✓ Active project confirmed: ${ACTIVE_PROJECT}"


# ------------------------------------------------------------------------------
# 1. Cloud Run
# ------------------------------------------------------------------------------

section "1/4 — Cloud Run"

if gcloud run services describe "${SERVICE}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" \
  >/dev/null 2>&1; then

  echo "Deleting Cloud Run service '${SERVICE}'..."

  gcloud run services delete "${SERVICE}" \
    --region="${REGION}" \
    --project="${PROJECT_ID}" \
    --quiet

  echo "✓ Cloud Run service deleted."
else
  echo "ℹ️ Cloud Run service '${SERVICE}' does not exist. Skipping."
fi


# ------------------------------------------------------------------------------
# 2. Artifact Registry
# ------------------------------------------------------------------------------

section "2/4 — Artifact Registry"

if gcloud artifacts repositories describe "${REPOSITORY}" \
  --location="${REGION}" \
  --project="${PROJECT_ID}" \
  >/dev/null 2>&1; then

  echo "Deleting Artifact Registry repository '${REPOSITORY}'..."
  echo "This also deletes all container images and tags inside it."

  gcloud artifacts repositories delete "${REPOSITORY}" \
    --location="${REGION}" \
    --project="${PROJECT_ID}" \
    --quiet

  echo "✓ Artifact Registry repository deleted."
else
  echo "ℹ️ Artifact Registry repository '${REPOSITORY}' does not exist. Skipping."
fi


# ------------------------------------------------------------------------------
# 3. BigQuery
# ------------------------------------------------------------------------------

section "3/4 — BigQuery"

if bq show \
  --project_id="${PROJECT_ID}" \
  "${PROJECT_ID}:${BIGQUERY_DATASET}" \
  >/dev/null 2>&1; then

  echo "Deleting BigQuery dataset '${BIGQUERY_DATASET}' and all tables..."

  bq rm \
    -r \
    -f \
    -d \
    "${PROJECT_ID}:${BIGQUERY_DATASET}"

  echo "✓ BigQuery dataset deleted."
else
  echo "ℹ️ BigQuery dataset '${BIGQUERY_DATASET}' does not exist. Skipping."
fi


# ------------------------------------------------------------------------------
# 4. Cloud Build Storage Bucket
# ------------------------------------------------------------------------------

section "4/4 — Cloud Build Storage"

BUCKET_URI="gs://${CLOUDBUILD_BUCKET}"

if gcloud storage buckets describe "${BUCKET_URI}" \
  --project="${PROJECT_ID}" \
  >/dev/null 2>&1; then

  echo "Deleting Cloud Build bucket '${BUCKET_URI}' and all objects..."

  gcloud storage rm \
    --recursive \
    "${BUCKET_URI}"

  echo "✓ Cloud Build bucket deleted."
else
  echo "ℹ️ Cloud Build bucket '${BUCKET_URI}' does not exist. Skipping."
fi


# ------------------------------------------------------------------------------
# Verification
# ------------------------------------------------------------------------------

section "Verification"

echo ""
echo "Cloud Run:"
gcloud run services list \
  --platform=managed \
  --project="${PROJECT_ID}" \
  --format="table(metadata.name,location)" || true

echo ""
echo "Artifact Registry:"
gcloud artifacts repositories list \
  --project="${PROJECT_ID}" \
  --format="table(name,format,location)" || true

echo ""
echo "BigQuery datasets:"
bq ls "${PROJECT_ID}:" || true

echo ""
echo "Cloud Storage buckets:"
gcloud storage buckets list \
  --project="${PROJECT_ID}" \
  --format="value(name)" || true

echo ""
echo "Preserved Secret Manager secrets:"
gcloud secrets list \
  --project="${PROJECT_ID}" \
  --format="value(name)" || true

echo ""
echo "Preserved Service Accounts:"
gcloud iam service-accounts list \
  --project="${PROJECT_ID}" \
  --format="value(email)" || true


# ------------------------------------------------------------------------------
# Final
# ------------------------------------------------------------------------------

echo ""
echo "======================================================================"
echo "✅ AI Search Journey Lab GCP cleanup complete."
echo ""
echo "Deleted:"
echo "  ✓ Cloud Run"
echo "  ✓ Artifact Registry"
echo "  ✓ BigQuery dataset"
echo "  ✓ Cloud Build storage"
echo ""
echo "Preserved:"
echo "  ✓ GCP project"
echo "  ✓ Gemini API key / Secret Manager"
echo "  ✓ Google Maps API key / Secret Manager"
echo "  ✓ Service Accounts"
echo "  ✓ IAM"
echo "  ✓ Enabled APIs"
echo ""
echo "Local Docker / Grafana / Tempo / Prometheus are unaffected."
echo "======================================================================"