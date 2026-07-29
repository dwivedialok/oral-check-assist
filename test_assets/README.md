Place test images here for E2E integration tests.

Required structure:
  normal/   - 5 benign oral cavity images (front_view.jpg, right_cheek.jpg, left_cheek.jpg, tounge.jpg, palate.jpg)
  opmd/     - 5 OPMD oral cavity images (same filenames; note the `tounge.jpg` spelling matches the test harness)
  unknown/  - 5 images (same filenames) intended to trigger the **strong** Unknown/OOD gate
              (5-class top == `Unknown` and P(Unknown) > 0.6 → excluded from aggregation).
              **Important:** random “non-oral” photos (landscapes, objects, skin close-ups) often **do not**
              satisfy this — the model may still predict Healthy/Benign with higher probability. For the
              all-unknown E2E scenario to **pass** (not skip), every file must produce that gate; otherwise
              the test reports `skipped_partial_ood` and you should swap in stronger negative examples per slot.

These images are used by integration_test/screening_e2e_test.dart.
Tests are automatically skipped when images are absent.
