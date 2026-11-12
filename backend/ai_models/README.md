# ai_models/ - trained model goes here

Put these two files (produced by `training/train_mobilenetv2_colab.ipynb`) in this folder:

| File | Purpose |
|---|---|
| `monument_model.keras` | Trained MobileNetV2 classifier (4 classes) |
| `class_names.json` | Class order used in training, e.g. `["lotus_mahal","other","stone_chariot","vittala_temple"]` |

No model is shipped with this project. Until you train one, `/identify` returns **clearly labelled mock data**.
Paths can be changed with `HERITAGE_MODEL_PATH` and `HERITAGE_LABELS_PATH`.
