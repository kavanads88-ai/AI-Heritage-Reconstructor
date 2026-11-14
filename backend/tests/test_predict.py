import io
from PIL import Image
from fastapi.testclient import TestClient

from app.main import create_app

client = TestClient(create_app())


def _make_dummy_image_bytes() -> bytes:
    img = Image.new("RGB", (100, 100), color=(128, 64, 32))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


def test_predict_endpoint_success():
    img_bytes = _make_dummy_image_bytes()
    response = client.post(
        "/predict",
        files={"file": ("test_monument.jpg", img_bytes, "image/jpeg")},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert "predicted_label" in data
    assert "confidence_percentage" in data
    assert "damage_analysis" in data
    assert "Visual indicator only - not a structural engineering assessment." in data["damage_analysis"]["disclaimer"]
    assert data["damage_analysis"]["annotated_image_base64"].startswith("data:image/jpeg;base64,")


def test_predict_endpoint_no_file():
    response = client.post("/predict")
    assert response.status_code == 422
