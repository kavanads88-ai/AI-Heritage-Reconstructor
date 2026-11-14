# Dataset (not committed)

One folder per class: `stone_chariot`, `vittala_temple`, `lotus_mahal`, `other`.
Aim for 150–250 photos per monument and 200+ in `other` (other Hampi structures, other temples, random scenes).
Vary angle, distance, light, crowds and phone cameras. Record author + licence for every image that is not yours
in `dataset\sources.csv` (filename, source URL, author, licence).
Split **before** augmenting: `python scripts\split_dataset.py --src dataset --dst dataset_split`.
No images are included in this repository.
