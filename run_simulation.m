% Master Runner & Verification Script for Zonal Automotive Ethernet Gateway
% Simulates Nominal, DoS Attack, and IEEE 802.1Qci Protected Scenarios.
% Generates comparative plots and safety compliance reports.

function run_simulation()
    clear; clc; close all;
    fprintf('=================================================================\n');
    fprintf(' ZONAL AUTOMOTIVE ETHERNET GATEWAY: ATTACK & DEFENSE SIMULATION \n');
    fprintf('=================================================================\n\n');

    % 1. Load Parameters
    cfg = parameters();
    fprintf('Loaded network parameters (100BASE-T1, 32 KB Gateway Buffer).\n');

    % 2. Check for Simulink availability
    hasSimulink = license('test', 'Simulink') && ~isempty(which('sim'));
    if hasSimulink
        fprintf('[Info] Simulink detected. Generating/updating Simulink model file...\n');
        try
            build_simulink_model();
        catch ME
            fprintf('[Warning] Simulink model generation encountered: %s\n', ME.message);
            fprintf('Falling back to direct numerical simulation core.\n');
        end
    else
        fprintf('[Info] Running discrete-event queuing simulation engine.\n');
    end

    % 3. Execute Scenarios
    fprintf('\nExecuting Scenario 1: Nominal Operations (No Attack)...\n');
    cfgNominal = cfg;
    cfgNominal.dos.enabled = false;
    cfgNominal.ransom.enabled = false;
    resNominal = zonal_gateway_core(cfgNominal, false);

    fprintf('Executing Scenario 2: Unprotected Gateway Under DoS & Ransomware...\n');
    cfgAttack = cfg;
    cfgAttack.dos.enabled = true;
    cfgAttack.ransom.enabled = true;
    resUnprotected = zonal_gateway_core(cfgAttack, false);

    fprintf('Executing Scenario 3: Protected Gateway (IEEE 802.1Qci Active)...\n');
    resProtected = zonal_gateway_core(cfgAttack, true);

    % 4. Print Summary Diagnostics Report
    print_report('Nominal Operation', resNominal, cfg);
    print_report('Unprotected Under Attack', resUnprotected, cfg);
    print_report('IEEE 802.1Qci Protected Under Attack', resProtected, cfg);

    % 5. Generate Multi-Panel Visualizations
    generate_figures(cfg, resNominal, resUnprotected, resProtected);

    fprintf('\n[Success] Simulation complete. Plots saved to: %s\n', fullfile(pwd, 'gateway_attack_defense_analysis.png'));
end

%% Helper: Formatted Diagnostic Report
function print_report(scenarioName, res, cfg)
    fprintf('\n-----------------------------------------------------------------\n');
    fprintf(' SCENARIO: %s\n', scenarioName);
    fprintf('-----------------------------------------------------------------\n');
    fprintf(' Critical Stream Packets Sent   : %d\n', res.critTotalCount);
    fprintf(' Critical Stream Packets Lost   : %d (Loss Rate: %.2f%%)\n', res.critDropCount, res.critLossRatio * 100);
    fprintf(' Best-Effort Packets Lost       : %d (Loss Rate: %.2f%%)\n', round(res.beDropCount), res.beLossRatio * 100);
    
    if ~isempty(res.critLatencies)
        maxLat = max(res.critLatencies) * 1e6;
        meanLat = mean(res.critLatencies) * 1e6;
        p99Lat = prctile(res.critLatencies, 99) * 1e6;
        fprintf(' Critical Latency (Mean)        : %.2f us\n', meanLat);
        fprintf(' Critical Latency (99th Pct)    : %.2f us\n', p99Lat);
        fprintf(' Critical Latency (Max Peak)    : %.2f us\n', maxLat);
    end
    
    fprintf(' ASIL-D Deadline Violations     : %d\n', res.deadlineViolations);
    if res.deadlineViolations == 0 && res.critDropCount == 0
        fprintf(' Safety Compliance Status       : [PASSED] (Deterministic delivery maintained)\n');
    else
        fprintf(' Safety Compliance Status       : [FAILED] (Safety hazard detected!)\n');
    end
end

%% Helper: Multi-Panel Visualization
function generate_figures(cfg, resNom, resUnp, resProt)
    fig = figure('Name', 'Automotive Zonal Gateway Attack Simulation', ...
        'Color', 'w', 'Position', [80, 80, 1200, 750], 'Visible', 'on');

    tMs = cfg.timeVec * 1e3;

    % Subplot 1: Gateway Buffer Occupancy
    subplot(2, 2, 1);
    plot(tMs, resNom.queueOccupancyKB, 'k--', 'LineWidth', 1.2); hold on;
    plot(tMs, resUnp.queueOccupancyKB, 'r', 'LineWidth', 1.5);
    plot(tMs, resProt.queueOccupancyKB, 'b', 'LineWidth', 1.5);
    yline(cfg.maxQueueSizeBytes / 1024, 'm--', 'Max Buffer (32 KB)', 'LineWidth', 1.2);
    xline(cfg.dos.startTime * 1e3, 'k:', 'DoS Start');
    xline(cfg.dos.endTime * 1e3, 'k:', 'DoS End');
    xlabel('Time (ms)'); ylabel('Buffer Occupancy (KB)');
    title('Zonal Gateway Buffer Memory Occupancy');
    legend('Nominal', 'Unprotected (Attack)', '802.1Qci Protected', 'Buffer Limit', 'Location', 'NorthWest');
    grid on; ylim([0, 36]);

    % Subplot 2: Safety-Critical Control Frame Latency
    subplot(2, 2, 2);
    if ~isempty(resUnp.critSendTimes)
        plot(resUnp.critSendTimes * 1e3, resUnp.critLatencies * 1e6, 'r-o', 'LineWidth', 1.2, 'MarkerSize', 4); hold on;
    end
    if ~isempty(resProt.critSendTimes)
        plot(resProt.critSendTimes * 1e3, resProt.critLatencies * 1e6, 'b-s', 'LineWidth', 1.2, 'MarkerSize', 4);
    end
    yline(cfg.crit.deadline * 1e6, 'k--', 'ASIL-D Deadline (1000 us)', 'LineWidth', 1.5);
    xline(cfg.ransom.startTime * 1e3, 'm:', 'Ransomware Trigger', 'LineWidth', 1.2);
    xlabel('Time (ms)'); ylabel('End-to-End Latency (\mus)');
    title('Safety-Critical ADAS/Chassis Frame Latency');
    legend('Unprotected', '802.1Qci Protected', 'Deadline Limit', 'Location', 'NorthWest');
    grid on;

    % Subplot 3: Cumulative Dropped Data
    subplot(2, 2, 3);
    plot(tMs, resUnp.droppedBytesCum / 1024, 'r', 'LineWidth', 1.5); hold on;
    plot(tMs, resProt.droppedBytesCum / 1024, 'b', 'LineWidth', 1.5);
    xlabel('Time (ms)'); ylabel('Dropped Traffic (KB)');
    title('Cumulative Dropped Traffic (Tail-Drop vs Ingress Policing)');
    legend('Unprotected (Queue Overflow)', '802.1Qci (Ingress Policed)', 'Location', 'NorthWest');
    grid on;

    % Subplot 4: Packet Drop Ratio Comparison
    subplot(2, 2, 4);
    lossData = [resUnp.critLossRatio * 100, resProt.critLossRatio * 100; ...
                resUnp.beLossRatio * 100, resProt.beLossRatio * 100];
    b = bar(lossData);
    b(1).FaceColor = [0.85 0.325 0.098]; % Red-orange
    b(2).FaceColor = [0 0.447 0.741];    % Blue
    set(gca, 'XTickLabel', {'Critical Stream', 'Best-Effort / Attack'});
    ylabel('Loss Ratio (%)');
    title('Frame Loss Ratio by Traffic Class');
    legend('Unprotected', '802.1Qci Protected', 'Location', 'NorthEast');
    grid on;

    % Save plot to disk
    saveas(fig, fullfile(pwd, 'gateway_attack_defense_analysis.png'));
end
