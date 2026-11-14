# API contract (FastAPI backend)

Base URL examples: `http://10.0.2.2:8000` (emulator), `http://127.0.0.1:8000` (USB + `adb reverse`),
`http://<PC-IPv4>:8000` (Wi-Fi). Interactive docs: `GET /docs` (Swagger UI).

All errors have the same shape: `{"detail": "Human-readable error message"}`.

| Status | Meaning |
|---|---|
| 400 | empty / corrupt / not an image, resolution too large |
| 404 | unknown monument, or asset (GLB) not installed |
| 413 | upload larger than `HERITAGE_MAX_UPLOAD_MB` (default 8) |
| 415 | image format other than JPEG / PNG / WEBP |
| 422 | the multipart field `file` is missing |
| 500 | server fault (e.g. `monuments.json` unreadable, label/model mismatch) |
| 503 | `/identify` has no model **and** mock mode is disabled |

Uploads: `multipart/form-data`, field name **`file`**.

---
## GET `/` — health check
```json
{ "status": "ok", "message": "Heritage API is running",
  "model_loaded": false, "model_status": "model_missing", "mock_identify_enabled": true }
```
`model_status`: `ready`, `model_missing`, `labels_missing`, `labels_invalid`, `tensorflow_missing`, `load_failed`.

## GET `/monuments`
```json
[ { "id": "stone_chariot", "name": "Stone Chariot", "location": "…", "thumbnail": null } ]
```
`thumbnail` is an absolute URL **only if the image file exists** in `backend/static/images/`, otherwise `null`.

## GET `/monuments/{id}`
Full record from `historical_data/monuments.json` plus a computed `assets` block:
```json
{ "id": "stone_chariot", "name": "…", "location": "…", "period": "…", "summary": "…",
  "architectural_significance": "…",
  "facts": [ { "text": "…", "status": "verified | secondary_source_checked | pending_verification", "source_ids": ["unesco_hampi"] } ],
  "sources": [ { "id": "unesco_hampi", "title": "…", "url": "https://…", "type": "primary | secondary" } ],
  "documented_elements": [ { "element": "…", "status": "…", "source": "…" } ],
  "hypothetical_elements": [ { "element": "…", "status": "…", "source": "…" } ],
  "reconstruction_target": "primary | secondary", "reconstruction_explanation": "…",
  "images": { "thumbnail": "file.jpg", "present": "file.jpg", "reconstruction": "file.jpg" },
  "model_file": "stone_chariot.glb",
  "assets": { "thumbnail_url": null, "present_image_url": null, "reconstruction_image_url": null,
              "has_present_image": false, "has_reconstruction_image": false,
              "has_model": false, "model_url": null } }
```
Optional field `ar_model_url`: a public https URL of the GLB for Android Scene Viewer.

## POST `/identify`
Response (values below are **illustrative only**):
```json
{ "monument_id": "stone_chariot", "name": "Stone Chariot", "confidence": 0.92, "is_unknown": false,
  "top3": [ { "id": "stone_chariot", "confidence": 0.92 } ],
  "threshold": 0.6, "is_mock": false, "message": null }
```
* Unknown (confidence < threshold or class `other`): `monument_id: null`, `name: "Unknown Monument"`, `is_unknown: true`.
* **No trained model + mock enabled:** `is_mock: true`, `confidence: null`, `top3: []` and a `message` starting
  with `MOCK DATA`. This is not an AI prediction.
* **No trained model + `HERITAGE_ALLOW_MOCK=false`:** HTTP 503.

## POST `/analyze-damage`
```json
{ "annotated_image_base64": "<JPEG, base64, no data: prefix>", "damage_area_percent": 4.21,
  "regions_found": 7, "message": "…possible visual indicators only…",
  "disclaimer": "Possible damage indicators from image processing — not a structural assessment.",
  "regions": [ { "x": 10, "y": 20, "width": 40, "height": 15, "area_percent": 0.4 } ],
  "image_width": 1024, "image_height": 768 }
```
Computed with OpenCV: resize (≤1024 px) → grayscale → Gaussian blur → Canny (median-based thresholds) →
adaptive threshold for dark crack-like pixels → morphological close/open → contours → area filter.
`damage_area_percent` = pixels of kept contours ÷ image pixels × 100. **This is not a trained model.**

## GET `/models/{id}`
`200` with `Content-Type: model/gltf-binary` (the `.glb`), or `404` `{"detail": "No 3D model is installed for … yet. Place '….glb' in backend/static/models/."}`.

## GET `/comparison/{id}`
```json
{ "monument_id": "stone_chariot", "present_url": null, "reconstruction_url": null,
  "has_reconstruction": false, "explanation": "The reconstruction image … has not been added yet, so no comparison can be shown. …",
  "disclaimer": "Historically informed hypothetical visualisation — not an exact depiction of the original." }
```
URLs are `null` when the file is not installed; the app then shows a labelled placeholder.

## Static files
`GET /static/images/<file>` and `GET /static/models/<file>` serve the contents of `backend/static/`.

## Configuration (environment variables)
| Variable | Default | Meaning |
|---|---|---|
| `HERITAGE_MODEL_PATH` | `backend/ai_models/monument_model.keras` | trained Keras model |
| `HERITAGE_LABELS_PATH` | `backend/ai_models/class_names.json` | class order used in training |
| `HERITAGE_CONFIDENCE_THRESHOLD` | `0.60` | below this → Unknown Monument |
| `HERITAGE_ALLOW_MOCK` | `true` | return labelled mock identification when no model |
| `HERITAGE_MAX_UPLOAD_MB` | `8` | upload size limit |
| `HERITAGE_MAX_IMAGE_MEGAPIXELS` | `40` | reject larger images |
| `HERITAGE_CORS_ORIGINS` | localhost origins | comma-separated; `*` only on a trusted network |
| `HERITAGE_DATA_FILE` | `historical_data/monuments.json` | history data |
| `HERITAGE_STATIC_DIR` | `backend/static` | images and GLB files |

PowerShell example: `$env:HERITAGE_CONFIDENCE_THRESHOLD = "0.7"; uvicorn app.main:app --host 0.0.0.0 --port 8000`
