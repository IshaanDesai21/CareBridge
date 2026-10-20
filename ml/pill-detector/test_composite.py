"""Tests for composite.py (stdlib unittest, synthetic RGBA fixtures)."""
import random
import unittest

import numpy as np
from PIL import Image, ImageDraw

import composite as C


def make_pill(color, size=(120, 60)):
    """RGBA ellipse pill with transparent margin."""
    w, h = size
    img = Image.new("RGBA", (w + 40, h + 40), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([20, 20, 20 + w, 20 + h], fill=color + (255,))
    return img


FIXTURE = {
    "lisinopril": [make_pill((250, 120, 120))],
    "atorvastatin": [make_pill((240, 240, 240), (100, 50))],
    "other": [make_pill((60, 90, 200), (90, 90))],
}
TARGETS = ["lisinopril", "atorvastatin"]


def iou(a, b):
    iw = min(a[2], b[2]) - max(a[0], b[0])
    ih = min(a[3], b[3]) - max(a[1], b[1])
    if iw <= 0 or ih <= 0:
        return 0.0
    inter = iw * ih
    return inter / ((a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - inter)


def corners(ann):
    c = ann["coordinates"]
    return (c["x"] - c["width"] / 2, c["y"] - c["height"] / 2,
            c["x"] + c["width"] / 2, c["y"] + c["height"] / 2)


class CompositeTests(unittest.TestCase):
    def gen(self, i):
        return C.compose_image(random.Random(i), FIXTURE, TARGETS, backgrounds=[])

    def test_no_overlap(self):
        for i in range(200):
            _, anns = self.gen(i)
            self.assertGreaterEqual(len(anns), 1)
            boxes = [corners(a) for a in anns]
            for j in range(len(boxes)):
                for k in range(j + 1, len(boxes)):
                    a, b = boxes[j], boxes[k]
                    self.assertEqual(iou(a, b), 0.0)
                    gap = max(b[0] - a[2], a[0] - b[2], b[1] - a[3], a[1] - b[3])
                    self.assertGreaterEqual(gap, C.MIN_GAP - 1e-6)

    def test_annotation_center_format(self):
        for i in range(200):
            img, anns = self.gen(i)
            self.assertEqual(img.size, (C.IMG_W, C.IMG_H))
            self.assertTrue(1 <= len(anns) <= 8)
            for a in anns:
                c = a["coordinates"]
                self.assertTrue(0 < c["x"] < C.IMG_W and 0 < c["y"] < C.IMG_H)
                self.assertTrue(c["width"] > 0 and c["height"] > 0)
                x0, y0, x1, y1 = corners(a)
                self.assertTrue(x0 >= 0 and y0 >= 0 and x1 <= C.IMG_W and y1 <= C.IMG_H)

    def test_target_fraction(self):
        for i in range(200):
            _, anns = self.gen(i)
            n_t = sum(a["label"] in TARGETS for a in anns)
            self.assertGreaterEqual(n_t / len(anns), 0.3)

    def test_box_is_tight_to_alpha(self):
        sprite, box = C.prepare_pill(random.Random(1), FIXTURE["lisinopril"][0])
        alpha = np.array(sprite.split()[3]) > 127
        ys, xs = np.where(alpha)
        self.assertEqual((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1), box)

    def test_label_strip_removed(self):
        img = Image.new("RGBA", (400, 300), (0, 0, 0, 0))
        ImageDraw.Draw(img).ellipse([150, 20, 250, 120], fill=(200, 50, 50, 255))
        ImageDraw.Draw(img).rectangle([0, 220, 399, 299], fill=(100, 200, 120, 255))
        out = C.strip_label(img)
        self.assertEqual(C._alpha_bbox(out, 127), (150, 20, 251, 121))
        sprite, box = C.prepare_pill(random.Random(3), img)
        self.assertLess(max(sprite.size), 0.23 * C.IMG_W)

    def test_reproducible(self):
        a, b = self.gen(7), self.gen(7)
        self.assertEqual(a[1], b[1])
        self.assertEqual(a[0].tobytes(), b[0].tobytes())

    def test_holdout_disjoint(self):
        rows = []
        for cls, n in [("lisinopril", 10), ("atorvastatin", 7), ("benzonatate", 3),
                       ("phenazopyridine", 2), ("other", 12)]:
            for k in range(n):
                rows.append({"ndc11": f"{cls[:3]}{k:03d}", "class": cls})
        train, hold = C.split_ndcs(rows, seed=42)
        self.assertFalse(set(train) & set(hold))
        self.assertEqual(set(train) | set(hold), {r["ndc11"] for r in rows})
        by_cls = {r["ndc11"]: r["class"] for r in rows}
        for cls in ["lisinopril", "atorvastatin", "benzonatate", "phenazopyridine", "other"]:
            self.assertGreaterEqual(sum(by_cls[n] == cls for n in hold), 1)
        self.assertEqual((train, hold), C.split_ndcs(rows, seed=42))


if __name__ == "__main__":
    unittest.main()
