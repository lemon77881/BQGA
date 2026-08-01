# BQGA — Binary Quantum Genetic Algorithm with Diversity-Guided Phase Transitions

Reference implementation of the search-control components of the Binary Quantum
Genetic Algorithm with Diversity-Guided Phase Transitions (BQGA) for CT image
enhancement.

> This repository accompanies a manuscript currently under peer review. It is
> made available so that the reviewers can inspect the mechanisms described in
> Section 3 of the manuscript. It will be replaced by the archival release upon
> acceptance.

## Contents

```
src/
  bqga_parameters.m      Parameter settings of Table 1
  bqga_diversity.m       Four-dimensional diversity quantification (Eqs. 8-13)
                         and phase classification with hysteresis (Eq. 14)
  bqga_phase_strategy.m  Phase-specific quantum walk parameters (Eq. 15) and
                         phase-transition shock
  bqga_quantum_walk.m    Phase-modulated coin operator (Eq. 16), quantum walk
                         (Eq. 167 and gradient-aware mutation (Eq. 18)
docs/
  EQUATION_MAP.md        Equation-to-code map with line numbers
  DATA.md                Access to the CHAOS and LiTS2017 benchmarks
```

`docs/EQUATION_MAP.md` maps every equation of Section 3 to the corresponding
lines of source, and is the recommended entry point for inspection.

## Requirements

MATLAB R2024a or later. No toolbox beyond the base product is required by the
released files.

## Usage

The released files are the search-control operators, intended to be inspected
and exercised individually. The following sequence reproduces one generation of
the phase-control loop:

```matlab
addpath('src');
params = bqga_parameters();

% A population of qubit chromosomes: theta, phi and Bloch coordinates
N = 8;
for i = 1:N
    th = pi * rand(1, params.n_dims);
    ph = 2*pi * rand(1, params.n_dims);
    pop(i).theta = th;
    pop(i).phi   = ph;
    bc = [sin(th).*cos(ph); sin(th).*sin(ph); cos(th)];
    pop(i).bloch_coords = bc;
end
fitness = rand(1, N);

% Eqs. (8)-(14): diversity quantification and phase detection
dm = bqga_diversity(pop, fitness, 5, params, 'LIQUID');

% Eq. (15): phase-specific step size and mutation rate
st = bqga_phase_strategy(dm, 5, params);

% Eqs. (16)-(18): quantum walk operators for the active phase
wp = bqga_quantum_walk('parameters', params, 5, dm.overall_diversity);
wp.mutation_rate_multiplier = st.mutation_rate_multiplier;
wp.edge_density = 0.12;   % E, extracted during preprocessing

[theta_new, phi_new] = bqga_quantum_walk('step', ...
    pop(1).theta(1), pop(1).phi(1), pop(2).theta(1), pop(2).phi(1), 1, wp);
[theta_mut, phi_mut] = bqga_quantum_walk('mutate', ...
    pop(1).theta(1), pop(1).phi(1), wp);
```

The phase state machine is driven by the caller: keep a phase variable,
initialise it to `'LIQUID'`, and update it from `dm.quantum_phase` after each
generation. The diversity function holds no internal state, so repeated and
parallel runs do not interfere.

## Implementation notes

- The coin bias of Eq. (16) couples linearly to the composite diversity score,
  giving `rho in [0.35, 0.65]`; the interference intensity of Eq. (18) decays as
  `exp(-D / tau)` with `tau = 0.5`. Both relations can be verified directly by
  evaluating `bqga_quantum_walk('parameters', ...)` across `D in [0, 1]`; the
  expected values are tabulated in `docs/EQUATION_MAP.md`.
- The gradient-aware weight `w_E = (1 + E)^{-1}` is driven by a volume-level
  edge-density scalar and therefore acts globally on the whole volume rather
  than selectively at individual voxels.
- BQGA is a quantum-inspired algorithm executed on classical hardware. The
  qubit encoding, walk and interference terms are algorithmic constructs that
  structure the search; no physical quantum speed-up is claimed.

## Scope

The files above implement the three contributions claimed in Section 1 of the
manuscript. Components that the manuscript specifies in full and that can be
reimplemented from it are not included: the composite fitness function and its
component mappings, the four-stage enhancement pipeline, the evaluation
metrics, the optimisation driver of Algorithm 1, and the input/output layer.
The baseline optimisers are the public implementations of their original
authors, used with the default control parameters reported in the corresponding
publications.

## Data

See `docs/DATA.md`. The CHAOS and LiTS2017 collections are obtained from their
official sources; no data is redistributed here.

## Licence

See `LICENSE`. The material is provided for the purpose of peer review and may
not be redistributed.
