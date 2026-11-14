# Backend (FastAPI)

```powershell
cd AI-Heritage-Reconstructor\backend
python -m venv venv
.\venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt          # API + OpenCV (no TensorFlow)
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```
Swagger UI: http://127.0.0.1:8000/docs · Tests: `pip install -r requirements-dev.txt` then `python -m pytest`.

`--host 0.0.0.0` lets a phone on the same Wi-Fi reach the server; for USB use `adb reverse tcp:8000 tcp:8000`.

## Layout
* `app/main.py` — app factory, CORS, static files, error handlers (`{"detail": …}`)
* `app/routers/` — thin HTTP layer (`health`, `monuments`, `identify`, `damage`, `assets`)
* `app/services/` — `classifier.py` (MobileNetV2 inference, lazy TensorFlow import), `damage.py` (OpenCV),
  `image_validation.py`, `monument_store.py` (JSON + asset lookup)
* `app/schemas/` — Pydantic response models
* `ai_models/` — put `monument_model.keras` and `class_names.json` here (see root README, section 7)
* `static/images`, `static/models` — assets served to the app

## Model integration
Without a model file the API still starts. `/identify` then returns clearly labelled mock data (or 503 if
`HERITAGE_ALLOW_MOCK=false`). With a model: `pip install -r requirements-ai.txt`. TensorFlow supports only
certain Python versions — check https://www.tensorflow.org/install/pip (3.11/3.12 recommended on Windows).
Input: 224×224 RGB, raw 0–255 (the model contains its own `Rescaling`). Class order comes from `class_names.json`.

## CORS
Default: localhost origins only. `HERITAGE_CORS_ORIGINS="http://localhost:3000,http://127.0.0.1:3000"`.
Use `*` only on a trusted local network; never expose this service publicly without HTTPS and authentication.

Full API reference: `../documentation/api_contract.md`.
