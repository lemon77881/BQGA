# Equation-to-code map

This document maps each equation of Section 3 of the manuscript to its
implementation in the released source files. Line numbers refer to the files
in `src/`.

## Section 3.3 — Multi-dimensional diversity quantification

| Equation | Quantity | File | Lines |
|---|---|---|---|
| Eq. (7) | Linear Bloch-to-parameter decoding `p_k = l_k + 0.5 (c_k + 1)(u_k - l_k)` | `bqga_diversity.m` | 312–317 |
| Eq. (8) | Parameter-space diversity `D_p` | `bqga_diversity.m` | 40–72 |
| Eq. (9) | Quantum-state diversity `D_q` (Fubini–Study angle) | `bqga_diversity.m` | 90–126 |
| Eq. (10) | Decoded-parameter diversity `D_m` | `bqga_diversity.m` | 127–181 |
| Eq. (11) | Fitness diversity `D_f` | `bqga_diversity.m` | 73–89 |
| Eq. (12) | Min–max normalisation of each component to [0, 1] | `bqga_diversity.m` | 64–69, 86, 121–123, 172–174 |
| Eq. (13) | Composite diversity score `D`, equal weights | `bqga_diversity.m` | 183–196 |

Each component is normalised in place, at the point where it is computed, so
that the aggregation of Eq. (13) reduces to an equal-weight mean over four
quantities already mapped to `[0, 1]`.

## Section 3.4 — Thermodynamic phase-transition control

| Equation / rule | Quantity | File | Lines |
|---|---|---|---|
| Eq. (14) | Phase classification, thresholds `tau_high = 0.65`, `tau_low = 0.25` | `bqga_diversity.m` | 197–248 |
| Section 3.4.1 | Hysteresis buffer of `±0.05` | `bqga_diversity.m` | 202, 208–247 |
| Eq. (15) | Step-size multiplier `s` and mutation-rate multiplier `m` per phase | `bqga_phase_strategy.m` | 40–116 |
| Section 3.4.3 | Phase-transition shock, one-generation adjustment | `bqga_phase_strategy.m` | 117–157 |

The three phases carry the multipliers of Eq. (14) relative to the baseline
values `s_b` and `m_b`:

| Phase | `s` | `m` | Lines |
|---|---|---|---|
| Plasma | `1.8 s_b` | `2.5 m_b` | `bqga_phase_strategy.m` 41–60 |
| Liquid | `s_b` | `m_b` | `bqga_phase_strategy.m` 62–86 |
| Crystal | `0.3 s_b` | `0.2 m_b` | `bqga_phase_strategy.m` 88–116 |

## Section 3.5 — Phase-adaptive quantum walk operator

| Equation | Quantity | File | Lines |
|---|---|---|---|
| Eq. (16) | Phase-modulated coin operator `C`, bias `rho = 0.5 + 0.3 (D - 0.5)` | `bqga_quantum_walk.m` | 57–62, 95–105 |
| Eq. (16) | Coin construction and application in the walk step | `bqga_quantum_walk.m` | 120–124, 144 |
| Eq. (17) | Quantum walk `\|x,d> <- S (C kron I) \|x,d>` | `bqga_quantum_walk.m` | 108–190 |
| Eq. (17) | Diffusion scale contracting as `1/sqrt(g)` | `bqga_quantum_walk.m` | 51–52, 147 |
| Eq. (18) | Gradient-aware mutation `delta_theta = I * N(0, sigma_m) * w_E` | `bqga_quantum_walk.m` | 193–267 |
| Eq. (18) | Interference intensity `I = exp(-D / tau)`, `tau = 0.5` | `bqga_quantum_walk.m` | 75–84, 226 |
| Eq. (18) | Gradient-aware weight `w_E = (1 + E)^{-1}` | `bqga_quantum_walk.m` | 218–223 |
| Eq. (18) | Phase-adaptive deviation `sigma_m = m * m_b` | `bqga_quantum_walk.m` | 209–215 |

## Table 1 — Parameter settings

All entries of Table 1 are defined in `bqga_parameters.m`:

| Parameter | Value | Line |
|---|---|---|
| Population size `N` | 50 | 14 |
| Maximum generations `G_max` | 75 | 15 |
| Number of parameters `K` | 5 | 16 |
| Baseline mutation rate `m_b` | 0.1 | 23 |
| Phase thresholds `tau_high`, `tau_low` | 0.65, 0.25 | 37–38 |
| Hysteresis buffer | 0.05 | 39 |
| Interference decay `tau` | 0.5 | 32 |
| Stagnation tolerance and patience | 0.01, 5 | 42–43 |
| Reinitialisation fraction | 10 % | 44 |
| Parameter bounds `[l_k, u_k]` | see Section 3.2 | 49–53 |
| Fitness weights | 0.30, 0.30, 0.20, 0.20 | 58–61 |

## Verification of the analytic ranges

The coupling relations of Eq. (16) and Eq. (18) can be checked directly by
evaluating `bqga_quantum_walk('parameters', ...)` over the admissible range of
the composite diversity score:

| `D` | `rho` (Eq. 16) | `I` (Eq. 18) |
|---|---|---|
| 0.00 | 0.350 | 1.0000 |
| 0.25 | 0.425 | 0.6065 |
| 0.50 | 0.500 | 0.3679 |
| 0.75 | 0.575 | 0.2231 |
| 1.00 | 0.650 | 0.1353 |

This reproduces the interval `rho in [0.35, 0.65]` stated after Eq. (16), and
the limits `I -> 1` as `D -> 0` and `I -> exp(-2) ~ 0.14` as `D -> 1` stated
after Eq. (18).

## Scope of this release

The released files cover the three contributions claimed in Section 1:
the diversity-guided phase-transition controller, the four-dimensional
diversity quantification framework, and the phase-adaptive quantum walk
operator with gradient-aware mutation.

Components that are fully specified in the manuscript and can be
reimplemented from it are not included here: the composite fitness function
and its component mappings (Eqs. 19–23), the four-stage enhancement pipeline
(Eqs. 24–27), the evaluation metrics (Eqs. 28–30), the optimisation driver of
Algorithm 1, and the input/output layer. 
