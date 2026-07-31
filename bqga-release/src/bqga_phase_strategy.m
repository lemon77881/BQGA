function strategy = bqga_phase_strategy(diversity_metrics, generation, ~)
% BQGA_PHASE_STRATEGY  Phase-specific quantum search parameters.
%
% Implements Section 3.4.2 and Section 3.4.3 of the manuscript:
%   Eq. (14) step-size multiplier s and mutation-rate multiplier m for the
%            plasma, liquid and crystal phases, relative to the baseline
%            values s_b and m_b;
%   phase-transition shock, a one-generation parameter adjustment applied
%            on entry into a new phase.
%
% The mapping is discontinuous by design: each phase carries a distinct
% parameter set rather than a smoothly interpolated schedule, so that the
% search reconfigures as soon as the composite diversity score crosses a
% phase boundary.
%
% Inputs
%   diversity_metrics : output of bqga_diversity
%   generation        : current generation index
%   params            : configuration struct from bqga_parameters, accepted
%                       for interface consistency with the other operators
%
% Output
%   strategy : struct with step-size and mutation multipliers, exploration
%              and convergence pressures, coin parameters and metadata.

    strategy = struct();

    quantum_phase     = diversity_metrics.quantum_phase;
    phase_temperature = diversity_metrics.phase_temperature;
    evolution_stage   = diversity_metrics.evolution_stage;
    phase_transition  = diversity_metrics.phase_transition;

    % Baseline values, corresponding to the liquid phase of Eq. (14)
    strategy.step_size_multiplier         = 1.0;
    strategy.mutation_rate_multiplier     = 1.0;
    strategy.exploration_intensity        = 0.5;
    strategy.convergence_pressure         = 0.5;
    strategy.quantum_interference_strength = 0.5;

    %% PHASE-SPECIFIC QUANTUM WALK PARAMETERS (Eq. 14)
    switch quantum_phase
        case 'PLASMA'
            % Global exploration: (s, m) = (1.8 s_b, 2.5 m_b)
            strategy.step_size_multiplier         = 1.8;
            strategy.mutation_rate_multiplier     = 2.5;
            strategy.exploration_intensity        = 0.95;
            strategy.convergence_pressure         = 0.05;
            strategy.quantum_interference_strength = 0.2;

            strategy.quantum_decoherence_rate     = 0.8;
            strategy.thermal_fluctuation_strength = 0.9;
            strategy.ballistic_spreading_factor   = 2.0;
            strategy.coin_randomization_level     = 0.9;

            if strcmp(evolution_stage, 'LATE')
                strategy.strategy_name        = 'PLASMA_LATE_EXPLORATION';
                strategy.step_size_multiplier = 1.5;
            else
                strategy.strategy_name = 'PLASMA_EXPLORATION';
            end

        case 'LIQUID'
            % Balanced search: (s, m) = (s_b, m_b)
            strategy.step_size_multiplier         = 1.0;
            strategy.mutation_rate_multiplier     = 1.0;
            strategy.exploration_intensity        = 0.5;
            strategy.convergence_pressure         = 0.5;
            strategy.quantum_interference_strength = 0.6;

            strategy.quantum_decoherence_rate     = 0.4;
            strategy.thermal_fluctuation_strength = 0.5;
            strategy.ballistic_spreading_factor   = 1.0;
            strategy.coin_randomization_level     = 0.5;

            switch evolution_stage
                case 'EARLY'
                    strategy.strategy_name         = 'LIQUID_EARLY_BALANCE';
                    strategy.exploration_intensity = 0.6;

                case 'MIDDLE'
                    strategy.strategy_name = 'LIQUID_MIDDLE_BALANCE';

                case 'LATE'
                    strategy.strategy_name        = 'LIQUID_LATE_BALANCE';
                    strategy.convergence_pressure = 0.6;
            end

        case 'CRYSTAL'
            % Local refinement: (s, m) = (0.3 s_b, 0.2 m_b)
            strategy.step_size_multiplier         = 0.3;
            strategy.mutation_rate_multiplier     = 0.2;
            strategy.exploration_intensity        = 0.1;
            strategy.convergence_pressure         = 0.95;
            strategy.quantum_interference_strength = 0.9;

            strategy.quantum_decoherence_rate     = 0.1;
            strategy.thermal_fluctuation_strength = 0.1;
            strategy.ballistic_spreading_factor   = 0.3;
            strategy.coin_randomization_level     = 0.1;

            switch evolution_stage
                case 'EARLY'
                    strategy.strategy_name         = 'CRYSTAL_EARLY_FORMATION';
                    strategy.step_size_multiplier  = 0.4;
                    strategy.exploration_intensity = 0.15;

                case 'MIDDLE'
                    strategy.strategy_name = 'CRYSTAL_MIDDLE_STRUCTURE';

                case 'LATE'
                    strategy.strategy_name        = 'CRYSTAL_LATE_REFINEMENT';
                    strategy.step_size_multiplier = 0.2;
                    strategy.convergence_pressure = 0.98;
            end
    end

    %% PHASE-TRANSITION SHOCK
    % Each transition event triggers a one-generation adjustment that
    % reinforces the new operational mode, so that the operators do not lag
    % behind the diversity signal in the generation following a transition.
    if phase_transition
        strategy.phase_transition_active = true;
        strategy.transition_description  = sprintf('%s to %s transition', ...
            diversity_metrics.previous_phase, quantum_phase);

        transition_shock_factor = 0.2;

        switch quantum_phase
            case 'PLASMA'
                % Entry into plasma: amplify step size and mutation rate
                strategy.step_size_multiplier = ...
                    strategy.step_size_multiplier * (1 + transition_shock_factor);
                strategy.mutation_rate_multiplier = ...
                    strategy.mutation_rate_multiplier * (1 + transition_shock_factor);

            case 'CRYSTAL'
                % Entry into crystal: strengthen convergence and coherence
                strategy.convergence_pressure = ...
                    strategy.convergence_pressure * (1 + transition_shock_factor);
                strategy.quantum_interference_strength = ...
                    min(1.0, strategy.quantum_interference_strength * (1 + transition_shock_factor));

            case 'LIQUID'
                % Entry into liquid from either extreme: moderate adjustment
                if strcmp(diversity_metrics.previous_phase, 'PLASMA')
                    strategy.exploration_intensity = ...
                        strategy.exploration_intensity * (1 - transition_shock_factor * 0.5);
                elseif strcmp(diversity_metrics.previous_phase, 'CRYSTAL')
                    strategy.exploration_intensity = ...
                        strategy.exploration_intensity * (1 + transition_shock_factor * 0.5);
                end
        end
    else
        strategy.phase_transition_active = false;
        strategy.transition_description  = 'No transition';
    end

    %% PARAMETER-SPECIFIC ADAPTATION
    % The phases act with different strength on the individual enhancement
    % parameters, since the window settings are the most sensitive and the
    % noise suppression dominates image quality.
    strategy.medical_adaptations = struct();

    switch quantum_phase
        case 'PLASMA'
            strategy.medical_adaptations.window_exploration_strength   = 0.9;
            strategy.medical_adaptations.contrast_exploration_strength = 0.8;
            strategy.medical_adaptations.noise_reduction_aggressiveness = 0.3;

        case 'LIQUID'
            strategy.medical_adaptations.window_exploration_strength   = 0.5;
            strategy.medical_adaptations.contrast_exploration_strength = 0.5;
            strategy.medical_adaptations.noise_reduction_aggressiveness = 0.5;

        case 'CRYSTAL'
            strategy.medical_adaptations.window_exploration_strength   = 0.1;
            strategy.medical_adaptations.contrast_exploration_strength = 0.1;
            strategy.medical_adaptations.noise_reduction_aggressiveness = 0.8;
    end

    %% SAFETY BOUNDS
    strategy.step_size_multiplier = max(0.1,  min(3.0, strategy.step_size_multiplier));
    strategy.mutation_rate_multiplier = max(0.05, min(4.0, strategy.mutation_rate_multiplier));
    strategy.exploration_intensity = max(0.05, min(1.0, strategy.exploration_intensity));
    strategy.convergence_pressure  = max(0.05, min(1.0, strategy.convergence_pressure));
    strategy.quantum_interference_strength = ...
        max(0.1, min(1.0, strategy.quantum_interference_strength));

    %% METADATA
    strategy.generation        = generation;
    strategy.diversity_value   = diversity_metrics.overall_diversity;
    strategy.phase_temperature = phase_temperature;
    strategy.quantum_phase     = quantum_phase;
    strategy.selection_reason  = sprintf('Phase: %s | Stage: %s | Temperature: %.2f', ...
        quantum_phase, evolution_stage, phase_temperature);
end
