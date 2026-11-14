# Adding real images, reconstructions and 3D models

The app and backend **never invent assets**. A file that does not exist is reported as missing and the
app shows a labelled placeholder. Add files, then restart nothing — the backend checks the disk on every request.

## 1. Photographs and reconstruction images → `backend\static\images\`
| File | Used for |
|---|---|
| `stone_chariot_present.jpg` | home card, details, "Present Appearance" |
| `stone_chariot_reconstruction.jpg` | "Proposed Reconstruction" (**primary target**) |
| `vittala_temple_present.jpg`, `lotus_mahal_present.jpg` | cards, details, comparison left side |
| `vittala_temple_reconstruction.jpg`, `lotus_mahal_reconstruction.jpg` | optional — add only if you really made them |

* Use your own photographs, or images whose licence allows reuse (e.g. Wikimedia Commons). Keep the
  author/licence in a CSV and show attribution in your report.
* Resize to ~1280 px wide, JPEG. Use **the same viewpoint** for present and reconstruction so the slider lines up.
* The reconstruction must be prepared by you (Blender render + photo editing + published references).
  Do not label it AI-generated. Cite what each reconstructed element is based on in `hypothetical_elements`.
* Optional: copy images to `mobile_app\assets\images\` using the same names to bundle them in the APK
  (shown when the backend is offline).

## 2. 3D models → `backend\static\models\`
`stone_chariot.glb` (primary). `vittala_temple.glb` / `lotus_mahal.glb` only if you have valid models and
the right to use them (record the licence/attribution).

Blender: File > Export > glTF 2.0 → Format **glTF Binary (.glb)**, tick *Apply Modifiers*, keep textures ≤ 2048 px,
aim for < 15 MB. Keep the `.blend` in `3d_models\blender\` and the export in `3d_models\exports\`.

To bundle a model in the APK (3D works offline): copy it to `mobile_app\assets\models\<id>.glb`.
**AR does not use the bundled copy** — Android Scene Viewer must download the model itself, so AR needs the
backend URL (`/models/<id>`) or a public `https` URL set as `"ar_model_url"` in `monuments.json`.

## 3. Historical text → `historical_data\monuments.json`
After editing, copy it into the app bundle:
```powershell
cd AI-Heritage-Reconstructor
.\scripts\sync_data.ps1
```
(`pytest` fails if the two copies differ.) Fact statuses: `verified` (checked on UNESCO/ASI/peer-reviewed
source — cite the exact page in `sources`), `secondary_source_checked`, `pending_verification`.
Facts without a source should not be added.

## 4. Check it worked
Open `http://127.0.0.1:8000/monuments/stone_chariot` — `assets.has_model`, `has_present_image` and
`has_reconstruction_image` must be `true`.
