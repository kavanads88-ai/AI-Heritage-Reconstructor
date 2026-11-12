import base64
import dataclasses
import io
import json

from PIL import Image

from conftest import REPO_ROOT, fake_classifier, make_crack_image, make_png


def upload(client, path, data, name="photo.png", ctype="image/png"):
    return client.post(path, files={"file": (name, data, ctype)})


# ------------------------------------------------------------------- health
def test_health_endpoint(client):
    r = client.get("/")
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "ok"
    assert body["model_loaded"] is False
    assert body["model_status"] == "model_missing"
    assert body["mock_identify_enabled"] is True


# ---------------------------------------------------------------- monuments
def test_monument_list(client):
    r = client.get("/monuments")
    assert r.status_code == 200
    items = r.json()
    assert [m["id"] for m in items] == ["stone_chariot", "vittala_temple", "lotus_mahal"]
    assert all(m["thumbnail"] is None for m in items)  # no images installed in tmp static dir


def test_monument_list_thumbnail_when_image_exists(client, tmp_settings):
    (tmp_settings.static_dir / "images" / "stone_chariot_present.jpg").write_bytes(b"x")
    items = client.get("/monuments").json()
    assert items[0]["thumbnail"].endswith("/static/images/stone_chariot_present.jpg")


def test_monument_detail(client):
    r = client.get("/monuments/stone_chariot")
    assert r.status_code == 200
    body = r.json()
    assert body["name"] == "Stone Chariot"
    assert body["sources"] and body["facts"]
    assert body["assets"]["has_model"] is False
    assert body["assets"]["model_url"] is None


def test_unknown_monument_returns_404(client):
    r = client.get("/monuments/does_not_exist")
    assert r.status_code == 404
    assert r.json() == {"detail": "Monument 'does_not_exist' was not found."}


def test_every_fact_has_status_and_sources_listed():
    data = json.loads((REPO_ROOT / "historical_data" / "monuments.json").read_text(encoding="utf-8"))
    for m in data:
        ids = {s["id"] for s in m["sources"]}
        assert m["sources"], f"{m['id']} has no sources"
        for fact in m["facts"]:
            assert fact["status"] in {"secondary_source_checked", "verified", "pending_verification"}
            for sid in fact["source_ids"]:
                assert sid in ids
            if fact["status"] != "pending_verification":
                assert fact["source_ids"], "a non-pending fact must cite a source"


def test_bundled_app_data_matches_backend_data():
    a = (REPO_ROOT / "historical_data" / "monuments.json").read_text(encoding="utf-8")
    b = (REPO_ROOT / "mobile_app" / "assets" / "data" / "monuments.json").read_text(encoding="utf-8")
    assert a == b, "Run scripts/sync_data.ps1 (or copy the file) to refresh the app's bundled data"


# ----------------------------------------------------------------- identify
def test_identify_rejects_non_image(client):
    r = upload(client, "/identify", b"this is not an image", "x.png")
    assert r.status_code == 400
    assert "valid image" in r.json()["detail"]


def test_identify_rejects_empty_file(client):
    r = upload(client, "/identify", b"", "x.png")
    assert r.status_code == 400


def test_identify_rejects_unsupported_format(client):
    buf = io.BytesIO()
    Image.new("RGB", (10, 10)).save(buf, format="GIF")
    r = upload(client, "/identify", buf.getvalue(), "x.gif", "image/gif")
    assert r.status_code == 415
    assert "Unsupported" in r.json()["detail"]


def test_identify_rejects_oversized_upload(client):
    r = upload(client, "/identify", b"0" * (2 * 1024 * 1024))
    assert r.status_code == 413
    assert "too large" in r.json()["detail"]


def test_identify_rejects_huge_resolution(make_client, tmp_settings):
    s = dataclasses.replace(tmp_settings, max_image_pixels=100)
    r = upload(make_client(s), "/identify", make_png((64, 64)))
    assert r.status_code == 400
    assert "resolution" in r.json()["detail"]


def test_identify_missing_file_field(client):
    r = client.post("/identify")
    assert r.status_code == 422
    assert "detail" in r.json() and isinstance(r.json()["detail"], str)


def test_identify_without_model_returns_visible_mock(client, png_bytes):
    r = upload(client, "/identify", png_bytes)
    assert r.status_code == 200
    body = r.json()
    assert body["is_mock"] is True
    assert body["confidence"] is None
    assert "MOCK" in body["message"]
    assert body["top3"] == []


def test_identify_without_model_and_mock_disabled_is_503(make_client, tmp_settings, png_bytes):
    s = dataclasses.replace(tmp_settings, allow_mock_identify=False)
    r = upload(make_client(s), "/identify", png_bytes)
    assert r.status_code == 503
    assert "not available" in r.json()["detail"]


def test_identify_confident_prediction(make_client, png_bytes):
    clf = fake_classifier([0.02, 0.03, 0.9, 0.05])  # stone_chariot
    r = upload(make_client(classifier=clf), "/identify", png_bytes)
    body = r.json()
    assert r.status_code == 200
    assert body["monument_id"] == "stone_chariot"
    assert body["name"] == "Stone Chariot"
    assert body["is_unknown"] is False and body["is_mock"] is False
    assert abs(body["confidence"] - 0.9) < 1e-4
    assert [p["id"] for p in body["top3"]] == ["stone_chariot", "vittala_temple", "other"]


def test_identify_below_threshold_is_unknown(make_client, png_bytes):
    clf = fake_classifier([0.1, 0.1, 0.5, 0.3])  # best = 0.5 < 0.6
    body = upload(make_client(classifier=clf), "/identify", png_bytes).json()
    assert body["is_unknown"] is True
    assert body["name"] == "Unknown Monument"
    assert body["monument_id"] is None
    assert body["top3"]


def test_identify_threshold_is_configurable(make_client, tmp_settings, png_bytes):
    probs = [0.1, 0.1, 0.5, 0.3]
    s = dataclasses.replace(tmp_settings, confidence_threshold=0.4)
    body = upload(make_client(s, fake_classifier(probs, 0.4)), "/identify", png_bytes).json()
    assert body["is_unknown"] is False
    assert body["monument_id"] == "stone_chariot"


def test_identify_other_class_is_unknown_even_if_confident(make_client, png_bytes):
    clf = fake_classifier([0.01, 0.97, 0.01, 0.01])
    body = upload(make_client(classifier=clf), "/identify", png_bytes).json()
    assert body["is_unknown"] is True
    assert body["monument_id"] is None


def test_identify_label_count_mismatch_is_500_not_crash(make_client, png_bytes):
    clf = fake_classifier([0.5, 0.5])  # 2 outputs vs 4 labels
    r = upload(make_client(classifier=clf), "/identify", png_bytes)
    assert r.status_code == 500
    assert "detail" in r.json()


# ------------------------------------------------------------ analyze-damage
def test_damage_returns_structured_result(client):
    r = upload(client, "/analyze-damage", make_crack_image())
    assert r.status_code == 200
    body = r.json()
    for key in ("annotated_image_base64", "damage_area_percent", "regions_found", "message", "disclaimer"):
        assert key in body
    assert body["disclaimer"].startswith("Possible damage indicators")
    assert 0 <= body["damage_area_percent"] <= 100
    assert body["regions_found"] >= 1
    assert len(body["regions"]) <= body["regions_found"]
    decoded = Image.open(io.BytesIO(base64.b64decode(body["annotated_image_base64"])))
    assert decoded.size == (body["image_width"], body["image_height"])


def test_damage_on_flat_image_finds_nothing(client):
    body = upload(client, "/analyze-damage", make_png((200, 200), (180, 180, 180))).json()
    assert body["regions_found"] == 0
    assert body["damage_area_percent"] == 0.0
    assert "not mean" in body["message"]


def test_damage_rejects_invalid_upload(client):
    r = upload(client, "/analyze-damage", b"nope")
    assert r.status_code == 400
    assert r.json()["detail"]


# --------------------------------------------------------- models / comparison
def test_model_missing_returns_helpful_404(client):
    r = client.get("/models/stone_chariot")
    assert r.status_code == 404
    assert "stone_chariot.glb" in r.json()["detail"]


def test_model_unknown_monument_404(client):
    assert client.get("/models/nope").status_code == 404


def test_model_served_when_present(client, tmp_settings):
    (tmp_settings.static_dir / "models" / "stone_chariot.glb").write_bytes(b"glTF-fake")
    r = client.get("/models/stone_chariot")
    assert r.status_code == 200
    assert r.headers["content-type"] == "model/gltf-binary"
    assert r.content == b"glTF-fake"


def test_comparison_without_assets_is_honest(client):
    r = client.get("/comparison/stone_chariot")
    assert r.status_code == 200
    body = r.json()
    assert body["present_url"] is None and body["reconstruction_url"] is None
    assert body["has_reconstruction"] is False
    assert "not been added" in body["explanation"]
    assert body["disclaimer"].startswith("Historically informed hypothetical visualisation")


def test_comparison_with_assets(client, tmp_settings):
    img = tmp_settings.static_dir / "images"
    (img / "stone_chariot_present.jpg").write_bytes(b"a")
    (img / "stone_chariot_reconstruction.jpg").write_bytes(b"b")
    body = client.get("/comparison/stone_chariot").json()
    assert body["has_reconstruction"] is True
    assert body["present_url"].endswith("/static/images/stone_chariot_present.jpg")
    assert body["reconstruction_url"].endswith("/static/images/stone_chariot_reconstruction.jpg")


def test_comparison_unknown_monument_404(client):
    assert client.get("/comparison/nope").status_code == 404


def test_path_traversal_in_data_file_is_ignored(tmp_path, make_client, tmp_settings):
    bad = tmp_path / "m.json"
    bad.write_text(json.dumps([{"id": "x", "name": "X", "location": "", "model_file": "../../secret.glb"}]))
    (tmp_path / "secret.glb").write_bytes(b"secret")
    s = dataclasses.replace(tmp_settings, data_file=bad)
    assert make_client(s).get("/models/x").status_code == 404
