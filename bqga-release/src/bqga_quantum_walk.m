function varargout = bqga_quantum_walk(action, varargin)
% BQGA_QUANTUM_WALK  Phase-adaptive quantum walk operator.
%
% Implements Section 3.5 of the manuscript:
%   Eq. (16) phase-modulated coin operator C, whose bias rho couples
%            linearly to the composite diversity score D;
%   Eq. (17) discrete-time quantum walk |x,d> <- S (C kron I) |x,d>;
%   Eq. (18) gradient-aware quantum mutation
%            delta_theta = I * N(0, sigma_m) * w_E.
%
% Dispatch:
%   wp = bqga_quantum_walk('parameters', params, generation, D)
%   [theta, phi, stats] = bqga_quantum_walk('step', theta, phi, ...
%                              target_theta, target_phi, k, wp)
%   [theta, phi] = bqga_quantum_walk('mutate', theta, phi, wp)
%
% A single entry point is used because MATLAB exposes only the first
% function defined in a file; the individual operators are implemented as
% local functions below.

    switch lower(action)
        case 'parameters'
            varargout{1} = walk_parameters(varargin{:});
        case 'step'
            [a, b, c] = walk_step(varargin{:});
            varargout{1} = a; varargout{2} = b; varargout{3} = c;
        case 'mutate'
            [a, b] = walk_mutation(varargin{:});
            varargout{1} = a; varargout{2} = b;
        otherwise
            error('bqga_quantum_walk: unknown action ''%s''.', action);
    end
end


% =====================================================================
function walk_params = walk_parameters(params, generation, D)
% Generation- and diversity-dependent quantum walk parameters.
%
% The diffusion scale contracts in proportion to 1/sqrt(g), narrowing the
% spread of the walk as the generation counter g advances, consistent with
% the finer search required in the crystal phase.

    if nargin < 3 || isempty(D) || ~isfinite(D)
        D = 0.5;
    end
    D = max(0, min(1, D));

    walk_params = struct();

    % Diffusion scale of Eq. (17): contracts as 1/sqrt(g)
    walk_params.diffusion_scale = 1 / sqrt(generation + 1);

    % Base step of the shift operator
    walk_params.base_step_size = params.shiftstep * params.quantum_ballistic_scaling;

    % Coin bias of Eq. (16): rho = 0.5 + 0.3 (D - 0.5), so that
    % rho lies in [0.35, 0.65] as D ranges over [0, 1]. At D = 0.5 the coin
    % is balanced; as D falls the diagonal entries dominate and bias the
    % walk toward exploitation; as D rises the off-diagonal entries dominate
    % and restore exploratory breadth.
    walk_params.coin_rho = 0.5 + 0.3 * (D - 0.5);

    % Parameter-dependent coin phases alpha and beta of Eq. (16). The window
    % settings are the most sensitive parameters and receive the smallest
    % phases; the contrast gain tolerates the widest exploration.
    walk_params.coin_phases = [
        pi/6;    % window centre
        pi/4;    % window width
        pi/3;    % contrast gain
        pi/8;    % noise suppression
        pi/4     % edge retention
    ];

    % Interference intensity of Eq. (18): I = exp(-D / tau) with tau = 0.5.
    % As D tends to 0 in the crystal phase, I tends to 1 and maximises the
    % perturbation available for local refinement; as D tends to 1 in the
    % plasma phase, I tends to exp(-2) and suppresses mutation so that the
    % ongoing global search is not disrupted.
    tau = 0.5;
    if isfield(params, 'interference_decay_tau') && ~isempty(params.interference_decay_tau)
        tau = params.interference_decay_tau;
    end
    walk_params.interference_intensity = exp(-D / max(tau, 1e-6));

    % Baseline mutation rate m_b of Table 1, used to form the
    % phase-adaptive standard deviation sigma_m = m * m_b.
    walk_params.baseline_mutation_rate = params.pm;

    walk_params.diversity = D;
end


% =====================================================================
function C = coin_operator(rho, alpha, beta)
% Phase-modulated coin operator of Eq. (16):
%
%   C = [ sqrt(rho)                    sqrt(1-rho) e^{i alpha}
%         sqrt(1-rho) e^{i beta}      -sqrt(rho) e^{i(alpha+beta)} ]

    rho = max(0, min(1, rho));
    C = [ sqrt(rho),                    sqrt(1 - rho) * exp(1i * alpha);
          sqrt(1 - rho) * exp(1i * beta), -sqrt(rho) * exp(1i * (alpha + beta)) ];
end


% =====================================================================
function [new_theta, new_phi, walk_stats] = walk_step(current_theta, current_phi, ...
        target_theta, target_phi, param_index, walk_params)
% One discrete-time quantum walk step of Eq. (17).
%
% Rather than moving directly toward the incumbent best solution, the coin
% operator places the qubit in a superposition of directions and the
% resulting interference biases the displacement toward regions that the
% walk reinforces constructively.

    walk_stats = struct('interference_strength', 0);

    try
        % Coin operator of Eq. (16) for the k-th enhancement parameter
        k     = min(max(1, param_index), numel(walk_params.coin_phases));
        alpha = walk_params.coin_phases(k);
        beta  = walk_params.coin_phases(max(1, mod(k, numel(walk_params.coin_phases)) + 1));
        C     = coin_operator(walk_params.coin_rho, alpha, beta);

        % Bloch angles expressed as a qubit state vector
        current_state = [cos(current_theta/2); ...
                         sin(current_theta/2) * exp(1i * current_phi)];

        target_state  = [cos(target_theta/2); ...
                         sin(target_theta/2) * exp(1i * target_phi)];

        % Direction toward the incumbent best solution
        direction_vector = target_state - current_state;
        direction_norm   = norm(direction_vector);

        if direction_norm > 1e-10
            direction_normalized = direction_vector / direction_norm;
        else
            direction_normalized = [1; 0];
        end

        % Coin application: (C kron I) acting on the coin register
        walked_state = C * current_state;

        % Conditional shift S, scaled by the contracting diffusion scale
        quantum_step_size = walk_params.base_step_size * walk_params.diffusion_scale;

        % Constructive interference along the direction of improvement
        interference_amplitude = abs(dot(walked_state, direction_normalized));
        interference_strength  = interference_amplitude^2;

        new_quantum_state = current_state ...
            + quantum_step_size * interference_strength * direction_normalized;

        % Renormalisation preserves the unit norm of the qubit state
        state_norm = norm(new_quantum_state);
        if state_norm > 1e-10
            new_quantum_state = new_quantum_state / state_norm;
        end

        % Recover the Bloch angles from the updated state
        amp0 = new_quantum_state(1);
        amp1 = new_quantum_state(2);

        new_theta = 2 * atan2(abs(amp1), abs(amp0));
        if abs(amp1) > 1e-10
            new_phi = angle(amp1 / amp0);
        else
            new_phi = current_phi;
        end

        new_theta = max(0, min(pi, real(new_theta)));
        new_phi   = mod(real(new_phi), 2*pi);

        if ~isfinite(new_theta) || ~isfinite(new_phi)
            new_theta = current_theta;
            new_phi   = current_phi;
            interference_strength = 0;
        end

        walk_stats.interference_strength = interference_strength;

    catch
        new_theta = current_theta;
        new_phi   = current_phi;
        walk_stats.interference_strength = 0;
    end
end


% =====================================================================
function [mutated_theta, mutated_phi] = walk_mutation(theta, phi, walk_params)
% Gradient-aware quantum mutation of Eq. (18):
%
%   delta_theta = I * N(0, sigma_m) * w_E
%
% where I = exp(-D / tau) is the interference intensity, sigma_m = m * m_b
% is the phase-adaptive standard deviation formed from the phase-specific
% multiplier m and the baseline rate m_b, and w_E = (1 + E)^{-1} is the
% gradient-aware weight computed from the volume-level edge density E.
%
% The weight w_E acts globally on the whole volume: volumes rich in
% anatomical boundaries receive a uniformly smaller mutation magnitude,
% which makes the search more conservative when structural content is dense
% and limits the introduction of halo artefacts.

    try
        % Phase-adaptive standard deviation sigma_m = m * m_b
        m   = 1.0;
        if isfield(walk_params, 'mutation_rate_multiplier') && ...
                ~isempty(walk_params.mutation_rate_multiplier)
            m = walk_params.mutation_rate_multiplier;
        end
        sigma_m = m * walk_params.baseline_mutation_rate;

        % Gradient-aware weight w_E = (1 + E)^{-1}
        E = 0;
        if isfield(walk_params, 'edge_density') && ~isempty(walk_params.edge_density) ...
                && isfinite(walk_params.edge_density)
            E = max(0, walk_params.edge_density);
        end
        w_E = 1 / (1 + E);

        % Interference intensity I = exp(-D / tau)
        I = walk_params.interference_intensity;

        % Polar-angle perturbation of Eq. (18)
        delta_theta = I * (sigma_m * randn) * w_E;

        % The coin operator randomises the walk direction of the mutation
        mutation_phase = 2*pi*rand;
        mutation_coin  = coin_operator(walk_params.coin_rho, mutation_phase, mutation_phase);

        current_state = [cos(theta/2); sin(theta/2) * exp(1i*phi)];
        mutated_state = mutation_coin * current_state;

        state_norm = norm(mutated_state);
        if state_norm > 1e-10
            mutated_state = mutated_state / state_norm;
        end

        amp0 = mutated_state(1);
        amp1 = mutated_state(2);

        mutated_theta = 2 * atan2(abs(amp1), abs(amp0));
        if abs(amp1) > 1e-10
            mutated_phi = angle(amp1 / amp0);
        else
            mutated_phi = phi;
        end

        % Apply the Eq. (18) perturbation to the polar angle
        mutated_theta = mutated_theta + delta_theta;

        mutated_theta = max(0, min(pi, real(mutated_theta)));
        mutated_phi   = mod(real(mutated_phi), 2*pi);

        if ~isfinite(mutated_theta) || ~isfinite(mutated_phi)
            mutated_theta = theta;
            mutated_phi   = phi;
        end

    catch
        mutated_theta = theta;
        mutated_phi   = phi;
    end
end
