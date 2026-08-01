function params = bqga_parameters()
% BQGA_PARAMETERS  Configuration of the Binary Quantum Genetic Algorithm
% with Diversity-Guided Phase Transitions (BQGA) for CT image enhancement.
%
% All values correspond to Table 1 of the manuscript.
%
% Returns
%   params : struct holding population, quantum-walk, phase-control,
%            parameter-bound and fitness-weight settings.

    % ---------------------------------------------------------------
    % Population and generation budget
    % ---------------------------------------------------------------
    params.popsize = 50;        % population size N
    params.maxgen  = 75;        % maximum generations G_max
    params.n_dims  = 5;         % number of enhancement parameters K

    % ---------------------------------------------------------------
    % Quantum operators
    % ---------------------------------------------------------------
    params.omega_max  = 0.9;
    params.omega_min  = 0.4;
    params.pm         = 0.1;            % baseline mutation rate m_b
    params.A          = 1.2;            % phase-transition shock factor
    params.shiftstep  = 0.05 * pi;      % base shift of the walk operator

    params.quantum_walk_enabled        = true;
    params.quantum_interference_strength = 0.8;
    params.quantum_ballistic_scaling     = 0.1;

    % Interference decay constant tau of Eq. (18): I = exp(-D / tau)
    params.interference_decay_tau = 0.5;

    % ---------------------------------------------------------------
    % Phase-transition control (Eq. 14)
    % ---------------------------------------------------------------
    params.tau_high          = 0.65;    % plasma threshold
    params.tau_low           = 0.25;    % crystal threshold
    params.hysteresis_margin = 0.05;    % hysteresis buffer

    % Stagnation-triggered selective reinitialisation
    params.stagnation_tol      = 0.01;  % |delta f| tolerance
    params.stagnation_patience = 5;     % consecutive generations
    params.reinit_fraction     = 0.10;  % fraction of worst individuals

    % ---------------------------------------------------------------
    % Enhancement parameter bounds [l_k, u_k]
    % ---------------------------------------------------------------
    params.window_center_range      = [0.100, 0.175];
    params.window_width_range       = [0.638, 0.743];
    params.global_contrast_range    = [1.000, 1.080];
    params.noise_reduction_range    = [0.050, 0.200];
    params.edge_preservation_range  = [1.000, 1.277];

    % ---------------------------------------------------------------
    % Fitness component weights (Eq. 19)
    % ---------------------------------------------------------------
    params.w_psnr_band = 0.30;
    params.w_cnr       = 0.30;
    params.w_med_snr   = 0.20;
    params.w_overpen   = 0.20;

    % PSNR trapezoidal band reward, breakpoints in dB
    params.psnr_low_cut    = 18;
    params.psnr_low_peak   = 24;
    params.psnr_high_peak  = 32;
    params.psnr_high_cut   = 42;
    params.psnr_band_floor = 0.10;

    % CNR linear-saturation reward and over-enhancement term
    params.cnr_ratio_lo     = 1.00;
    params.cnr_ratio_hi     = 1.30;
    params.snr_change_scale = 1.5;
    params.contrast_target  = 1.20;
    params.contrast_sigma   = 0.25;
end
