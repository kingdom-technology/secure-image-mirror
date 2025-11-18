# Secure-Image-Mirror
### Deterministic Vendor Image Mirroring → AWS ECR (with Digest Verification)

This repository provides a **secure, deterministic, repeatable pipeline** for mirroring third-party Docker images into **AWS Elastic Container Registry (ECR)** — ideal for regulated environments, GovCloud, IL5, or any organization that requires strict control over external container images.

The pipeline ensures:

- **Integrity & authenticity** – validated using immutable manifest digests (`sha256:...`)
- **Determinism** – pull-by-digest only when provided
- **Vendor flexibility** – automatic tag → digest resolution for vendors who do not expose digests

---

## Repository Contents

- **`mirror-vendor.sh`**  
  Pulls vendor images, validates digests, retags, and pushes to ECR.

- **`mirror-ai.sh`**  
  Mirrors images sourced from private or alternate AWS accounts.

- **`.circleci/config.yml`**  
  Pipeline definitions for mirroring workflows and digest resolution.

---

## Supported Services

| SERVICE                     | Vendor Source Image                         | Destination ECR Repo            |
|-----------------------------|---------------------------------------------|----------------------------------|
| `cke-core`                  | `docker.cke-cs.com/cs`                      | `vendor/cke-core`                |
| `cke-docx`                  | `docker.cke-cs.com/docx-converter`          | `vendor/cke-docx`                |
| `formio-enterprise`         | `formio/formio-enterprise`                  | `vendor/formio-enterprise`       |
| `formio-pdf`                | `formio/pdf-server`                         | `vendor/formio-pdf`              |
| `spell-checker`             | `webspellchecker/wproofreader`              | `vendor/spellcheck`              |
| `etlworks-app`              | `etlworks/etlworks-app`                     | `vendor/etlworks-app`            |
| `metabase`                  | `metabase/metabase-enterprise`              | `vendor/metabase`                |
| `genai-api`                 | `ACCOUNT_ID*/docshunter-genai-ai-api`       | `docshunter-genai-ai-api`        |
| `pdf-nlm-ingestor`          | `ACCOUNT_ID*/pdf-nlm-ingestor`              | `pdf-nlm-ingestor`               |
| `text-embeddings-inference` | `ACCOUNT_ID*/docshunter-genai-embeddings`   | `text-embeddings-inference`      |

---

## CircleCI Configuration

### Pipeline Parameters

- `workflow` – (`mirror-vendor` / `mirror-ai`)
- `SERVICE` – supported service key
- `TAG` – vendor tag (e.g. `5.11.1`)
- `DEST_TAG` – optional destination tag
- `EXPECTED_SHA` – linux/amd64 manifest digest
- `AWS_REGION` – defaults to `us-gov-west-1`

### Required Secrets

| Secret | Purpose |
|--------|---------|
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | Push to ECR |
| `AWS_SESSION_TOKEN` | If using STS |
| `CKE_PASS` | Required for CKEditor images |

---

## Authenticity & Verification Model

1. Resolve vendor tag → **manifest digest**
2. Pull by manifest digest (immutable + verifiable)
3. Validate repoDigest matches `EXPECTED_SHA`
4. Push to ECR only after successful verification

This prevents:

- Tag drift  
- Poisoned upstream registries  
- Accidental version mismatches  
- Supply-chain substitution attacks  

---

# Why This Matters for FedRAMP & IL5

### 1. **Supports SR-9 / SR-10 / SR-11 — Verify Authenticity of Third-Party Software**
Digest-verified mirroring ensures:
- The artifact is authentic  
- The artifact is untampered  
- The artifact is immutable & auditable  

### 2. **Protects IL5 Systems From Upstream Registry Compromise**
IL5 systems **must not rely** on public registries at runtime.  
This pipeline creates a **secure, 1-way ingestion point** into GovCloud ECR.

### 3. **Enables Deterministic, Auditable Deployments**
Auditors often ask:
- “Show the exact digest deployed.”
- “Prove the artifact hasn’t changed.”

This pipeline produces clear, timestamped evidence.

### 4. **Reduces Supply-Chain Risk (NIST 800-53 SA-12 / SA-13)**
By enforcing digest verification, the pipeline strengthens:
- Supply-chain trust  
- Transparency  
- Reproducibility  
- SLSA compliance  

### 5. **Centralizes All Third‑Party Software Inside GovCloud**
All vendor images become:
- Internal  
- Versioned  
- KMS-encrypted  
- Centrally managed  

A strong story for FedRAMP High & IL5 boundary security.

---

## Local Example

```bash
export AWS_REGION=us-gov-west-1
export SERVICE=cke-core
export TAG=4.25.0
export EXPECTED_SHA=sha256:your_digest_here
export CKE_PASS=******

./mirror-vendor.sh
```

---

## Summary

Secure-Image-Mirror is a **production-grade pipeline** for regulated environments requiring:

- Verified third-party artifacts  
- Deterministic container ingestion  
- Audit-ready deployment records  
- GovCloud-compatible ECR mirroring  

Typical Use Cases:

- GovCloud customers needing deterministic vendor image intake
- FedRAMP High / IL5 SaaS platforms consuming third-party containers
- Enterprises implementing SLSA-style container supply chain controls

Suitable for **FedRAMP High**, **DoD IL5**, and **enterprise supply chain security**.

