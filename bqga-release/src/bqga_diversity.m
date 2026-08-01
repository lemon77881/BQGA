function diversity_metrics = bqga_diversity(population, fitness_values, generation, params, prev_phase)
% BQGA_DIVERSITY  Multi-dimensional diversity quantification and
% thermodynamic phase detection.
%
% Implements Section 3.3 and Section 3.4.1 of the manuscript:
%   Eq. (8)  D_p : parameter-space diversity
%   Eq. (9)  D_q : quantum-state diversity (Fubini-Study angle)
%   Eq. (10) D_m : decoded-parameter diversity
%   Eq. (11) D_f : fitness diversity
%   Eq. (12) min-max normalisation of each component
%   Eq. (13) D   : composite diversity score, equal weights
%   Eq. (14) phase classification with hysteresis buffer
%
% The previous-phase state machine is an explicit input rather than
% internal state, so the function is free of hidden state across calls,
% safe for repeated and parallel runs, and independently testable.
% Callers keep their own phase variable, initialise it to 'LIQUID' at the
% start of every run, and update it from diversity_metrics.quantum_phase.
%
% Inputs
%   population     : struct array with fields theta, phi, bloch_coords
%   fitness_values : vector of fitness values for the current population
%   generation     : current generation index
%   params         : configuration struct from bqga_parameters
%   prev_phase     : 'PLASMA' | 'LIQUID' | 'CRYSTAL'
%
% Output
%   diversity_metrics : struct with the four component metrics, the
%                       composite score, and the resolved phase state.

    if nargin < 5 || isempty(prev_phase) || ~ischar(prev_phase) || ...
            ~ismember(prev_phase, {'PLASMA', 'LIQUID', 'CRYSTAL'})
        prev_phase = 'LIQUID';
    end

    diversity_metrics = struct();
    popsize = length(population);

    try
        %% 1. PARAMETER-SPACE DIVERSITY (Eq. 8)
        %   D_p = 0.5 * (sqrt(Var(theta)) + sqrt(Var(phi)))
        % std(.) equals sqrt(Var(.)). The per-qubit standard deviations are
        % averaged across the K qubit dimensions to obtain a scalar.
        all_theta = zeros(popsize, params.n_dims);
        all_phi   = zeros(popsize, params.n_dims);
        n_valid   = 0;

        for i = 1:popsize
            if length(population(i).theta) >= params.n_dims
                n_valid = n_valid + 1;
                all_theta(n_valid, :) = population(i).theta(1:params.n_dims);
                all_phi(n_valid, :)   = population(i).phi(1:params.n_dims);
            end
        end
        all_theta = all_theta(1:n_valid, :);
        all_phi   = all_phi(1:n_valid, :);

        if size(all_theta, 1) > 1
            theta_std = mean(std(all_theta, 0, 1));
            phi_std   = mean(std(all_phi,   0, 1));
            % Normalisation to [0, 1] (Eq. 11): theta lies in [0, pi] so its
            % maximum standard deviation is pi/2; phi lies in [0, 2*pi] so
            % its maximum is pi. The metric saturates at 1 for a fully
            % spread population.
            Dp_raw        = 0.5 * (theta_std + phi_std);
            Dp_norm_denom = 0.5 * (pi/2 + pi);
            diversity_metrics.parameter_diversity = ...
                min(1, max(0, Dp_raw / max(Dp_norm_denom, 1e-6)));
        else
            diversity_metrics.parameter_diversity = 0.1;
        end

        %% 2. FITNESS DIVERSITY (Eq. 11)
        %   D_f = sigma_f / (mu_f + epsilon)
        % Saturated at 1 because the ratio diverges as the fitness mean
        % approaches zero, and tends to 0 for a near-uniform population.
        if length(fitness_values) > 1
            fitness_std  = std(fitness_values);
            fitness_mean = mean(fitness_values);
            if abs(fitness_mean) > 1e-10
                Df_raw = fitness_std / (abs(fitness_mean) + 1e-10);
            else
                Df_raw = fitness_std;
            end
            diversity_metrics.fitness_diversity = min(1, max(0, Df_raw));
        else
            diversity_metrics.fitness_diversity = 1.0;
        end

        %% 3. QUANTUM-STATE DIVERSITY (Eq. 9, Fubini-Study angle)
        %   D_q = (2 / (N(N-1))) * sum_{i<j} arccos(|<psi_i | psi_j>|)
        % For a single qubit |psi> = cos(theta/2)|0> + e^{i phi} sin(theta/2)|1>,
        %   |<psi_i | psi_j>| = | cos(theta_i/2) cos(theta_j/2)
        %                       + e^{i (phi_j - phi_i)} sin(theta_i/2) sin(theta_j/2) |
        % A chromosome is a tensor product of K independent single-qubit
        % states, so the chromosome-level overlap is the per-qubit product.
        % The Fubini-Study angle lies in [0, pi/2] for orthogonal states,
        % hence the division by pi/2 maps the metric to [0, 1] (Eq. 12).
        if popsize > 1
            Dq_sum  = 0;
            n_pairs = 0;
            for i = 1:popsize
                ti  = population(i).theta(1:params.n_dims);
                pi_ = population(i).phi(1:params.n_dims);
                for j = i+1:popsize
                    tj = population(j).theta(1:params.n_dims);
                    pj = population(j).phi(1:params.n_dims);
                    ip_per_q = abs( cos(ti/2).*cos(tj/2) ...
                                    + exp(1i*(pj - pi_)).*sin(ti/2).*sin(tj/2) );
                    ip_total = prod(ip_per_q);
                    ip_total = min(1, max(0, ip_total));
                    Dq_sum   = Dq_sum + acos(ip_total);
                    n_pairs  = n_pairs + 1;
                end
            end
            if n_pairs > 0
                Dq_raw = Dq_sum / n_pairs;
                diversity_metrics.quantum_diversity = ...
                    min(1, max(0, Dq_raw / (pi/2)));
            else
                diversity_metrics.quantum_diversity = 0.5;
            end
        else
            diversity_metrics.quantum_diversity = 0.5;
        end

        %% 4. DECODED-PARAMETER DIVERSITY (Eq. 10)
        %   D_m = (1/K) * sum_{k=1..K} sigma(p_k)
        % All five decoded parameters contribute: window centre, window
        % width, contrast gain, noise suppression and edge retention. Each
        % standard deviation is normalised by half of the corresponding
        % admissible range, so a fully spread population yields 1 per
        % parameter (Eq. 12).
        %
        % Eq. (10) refers to the spread of the linearly decoded parameters
        % across the population, so the decoding here is the plain
        % Bloch-to-range mapping of Eq. (7).
        try
            wc = zeros(1, popsize);
            ww = zeros(1, popsize);
            gc = zeros(1, popsize);
            nr = zeros(1, popsize);
            ep_arr = zeros(1, popsize);
            valid  = false(1, popsize);
            for i = 1:popsize
                if isempty(population(i).bloch_coords) ...
                        || size(population(i).bloch_coords, 2) < params.n_dims
                    continue;
                end
                bc = population(i).bloch_coords;
                wc(i) = bqga_map_to_range(bc(1, 1), params.window_center_range);
                ww(i) = bqga_map_to_range(bc(2, 1), params.window_width_range);
                gc(i) = bqga_map_to_range(bc(3, 1), params.global_contrast_range);
                if params.n_dims >= 4
                    nr(i) = bqga_map_to_range(bc(1, 2), params.noise_reduction_range);
                end
                if params.n_dims >= 5
                    ep_arr(i) = bqga_map_to_range(bc(2, 2), params.edge_preservation_range);
                end
                valid(i) = true;
            end

            wc = wc(valid); ww = ww(valid); gc = gc(valid);
            nr = nr(valid); ep_arr = ep_arr(valid);

            pieces = [];
            if length(wc)     > 1, pieces(end+1) = std(wc)     / max(diff(params.window_center_range)/2,     1e-6); end
            if length(ww)     > 1, pieces(end+1) = std(ww)     / max(diff(params.window_width_range)/2,      1e-6); end
            if length(gc)     > 1, pieces(end+1) = std(gc)     / max(diff(params.global_contrast_range)/2,   1e-6); end
            if length(nr)     > 1, pieces(end+1) = std(nr)     / max(diff(params.noise_reduction_range)/2,   1e-6); end
            if length(ep_arr) > 1, pieces(end+1) = std(ep_arr) / max(diff(params.edge_preservation_range)/2, 1e-6); end

            if ~isempty(pieces)
                diversity_metrics.medical_diversity = min(1, max(0, mean(pieces)));
            else
                diversity_metrics.medical_diversity = 0.1;
            end

        catch
            diversity_metrics.medical_diversity = 0.1;
        end

        %% 5. COMPOSITE DIVERSITY SCORE (Eq. 13, equal weights)
        %   D = (1/4) * (D_p + D_q + D_m + D_f)
        % Every component is already mapped to [0, 1] by the per-component
        % normalisation of Eq. (12), so the equal-weight mean is applied
        % directly.
        weights = [0.25, 0.25, 0.25, 0.25];
        components = [diversity_metrics.parameter_diversity, ...
                      diversity_metrics.fitness_diversity, ...
                      diversity_metrics.quantum_diversity, ...
                      diversity_metrics.medical_diversity];

        components = max(0, min(1, components));
        diversity_metrics.overall_diversity = sum(weights .* components);

        %% PHASE CLASSIFICATION WITH HYSTERESIS (Eq. 14)
        PLASMA_THRESHOLD  = params.tau_high;
        LIQUID_UPPER      = params.tau_high;
        LIQUID_LOWER      = params.tau_low;
        CRYSTAL_THRESHOLD = params.tau_low;
        HYSTERESIS_MARGIN = params.hysteresis_margin;

        current_diversity = diversity_metrics.overall_diversity;

        % The current phase is retained until D crosses the nominal
        % threshold displaced by the hysteresis margin in the direction of
        % departure, which prevents oscillatory switching near a boundary.
        switch prev_phase
            case 'PLASMA'
                if current_diversity < (LIQUID_UPPER - HYSTERESIS_MARGIN)
                    if current_diversity > LIQUID_LOWER
                        new_phase = 'LIQUID';
                    else
                        new_phase = 'CRYSTAL';
                    end
                else
                    new_phase = 'PLASMA';
                end

            case 'LIQUID'
                if current_diversity > (PLASMA_THRESHOLD + HYSTERESIS_MARGIN)
                    new_phase = 'PLASMA';
                elseif current_diversity < (CRYSTAL_THRESHOLD - HYSTERESIS_MARGIN)
                    new_phase = 'CRYSTAL';
                else
                    new_phase = 'LIQUID';
                end

            case 'CRYSTAL'
                if current_diversity > (LIQUID_LOWER + HYSTERESIS_MARGIN)
                    if current_diversity < LIQUID_UPPER
                        new_phase = 'LIQUID';
                    else
                        new_phase = 'PLASMA';
                    end
                else
                    new_phase = 'CRYSTAL';
                end

            otherwise
                new_phase = 'LIQUID';
        end

        diversity_metrics.quantum_phase    = new_phase;
        diversity_metrics.previous_phase   = prev_phase;
        diversity_metrics.phase_transition = ~strcmp(new_phase, prev_phase);

        %% PHASE-SPECIFIC PROPERTIES
        switch new_phase
            case 'PLASMA'
                diversity_metrics.phase_temperature    = 1.0;
                diversity_metrics.exploration_strength = 0.9;
                diversity_metrics.quantum_coherence    = 0.3;
                diversity_metrics.phase_description    = 'High-energy exploratory phase';

            case 'LIQUID'
                diversity_metrics.phase_temperature    = 0.5;
                diversity_metrics.exploration_strength = 0.5;
                diversity_metrics.quantum_coherence    = 0.6;
                diversity_metrics.phase_description    = 'Balanced exploration-exploitation';

            case 'CRYSTAL'
                diversity_metrics.phase_temperature    = 0.1;
                diversity_metrics.exploration_strength = 0.1;
                diversity_metrics.quantum_coherence    = 0.9;
                diversity_metrics.phase_description    = 'Crystallised exploitation phase';
        end

        %% COARSE DIVERSITY STATE
        switch new_phase
            case 'PLASMA'
                diversity_metrics.diversity_state = 'HIGH';
            case 'LIQUID'
                diversity_metrics.diversity_state = 'MEDIUM';
            case 'CRYSTAL'
                diversity_metrics.diversity_state = 'LOW';
        end

        %% EVOLUTION STAGE
        progress = generation / params.maxgen;
        if progress < 0.3
            diversity_metrics.evolution_stage = 'EARLY';
        elseif progress < 0.7
            diversity_metrics.evolution_stage = 'MIDDLE';
        else
            diversity_metrics.evolution_stage = 'LATE';
        end

    catch
        % Neutral fallback. The phase is forced back to LIQUID so that the
        % next generation re-enters the state machine from a defined state.
        diversity_metrics.parameter_diversity = 0.5;
        diversity_metrics.fitness_diversity   = 0.5;
        diversity_metrics.quantum_diversity   = 0.5;
        diversity_metrics.medical_diversity   = 0.5;
        diversity_metrics.overall_diversity   = 0.5;
        diversity_metrics.diversity_state     = 'MEDIUM';
        diversity_metrics.evolution_stage     = 'MIDDLE';

        diversity_metrics.quantum_phase        = 'LIQUID';
        diversity_metrics.previous_phase       = prev_phase;
        diversity_metrics.phase_transition     = ~strcmp('LIQUID', prev_phase);
        diversity_metrics.phase_temperature    = 0.5;
        diversity_metrics.exploration_strength = 0.5;
        diversity_metrics.quantum_coherence    = 0.6;
        diversity_metrics.phase_description    = 'Fallback balanced phase';
    end
end


function value = bqga_map_to_range(coord, range)
% BQGA_MAP_TO_RANGE  Linear Bloch-to-parameter mapping of Eq. (7):
%   p_k = l_k + 0.5 * (c_k + 1) * (u_k - l_k),  c_k in [-1, 1].
    coord = max(-1, min(1, coord));
    value = range(1) + 0.5 * (coord + 1) * (range(2) - range(1));
end
