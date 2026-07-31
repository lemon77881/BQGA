# Data

The evaluation reported in Section 4 uses two public benchmark collections. No
redistribution is provided here: both are obtained directly from their official
sources under the terms set by their respective organisers.

## CHAOS — Combined Healthy Abdominal Organ Segmentation

Abdominal CT volumes of healthy subjects, used for the main comparative
evaluation.

- Official site: https://chaos.grand-challenge.org/
- Data download: https://chaos.grand-challenge.org/Download/
- Registration with the challenge organisers is required. The CT track
  provides DICOM series with ground-truth liver masks.

## LiTS2017 — Liver Tumor Segmentation Challenge

Lesion-bearing abdominal CT volumes, used to extend the evaluation to cases
containing focal pathology.

- Official site: https://competitions.codalab.org/competitions/17094
- Mirror hosted by the organisers: https://academictorrents.com/details/27772adef6f563a1ecc0ae19a528b956e6c803ce
- The training set provides volumes with liver and lesion annotations.

## Preprocessing applied before optimisation

Volumes are conditioned as described in Section 3.1 before the search begins:

1. Intensity outliers are removed by clamping to the empirical `[Q1, Q99]`
   range of the volume.
2. The clamped volume is normalised to the unit interval, preserving the
   relative ordering of tissue classes.

The descriptors used by the algorithm are extracted from the normalised
volume: the tissue histogram, the noise level estimated over locally
homogeneous regions, and the edge density `E` that enters the gradient-aware
weight `w_E` of Eq. (17).

## Parameter bounds and transfer

The bounds listed in Section 3.2 are calibrated for the abdominal CT data used
in this study. Transfer to a different scanner, reconstruction kernel or
acquisition protocol would in general require recalibration of the bounds to
the target intensity characteristics. The form of the phase-transition control
does not depend on the specific bound values.
