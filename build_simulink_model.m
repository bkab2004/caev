% Programmatically generates the Simulink model for Zonal Automotive Ethernet Gateway
% Creates: zonal_gateway_model.slx in D:\caev

function build_simulink_model()
    mdl = 'zonal_gateway_model';

    fprintf('========================================================\n');
    fprintf(' Generating Simulink Model: %s.slx ...\n', mdl);
    fprintf('========================================================\n');

    % Check if model is already open, if so close without saving
    if bdIsLoaded(mdl)
        close_system(mdl, 0);
    end

    % Create new Simulink system
    new_system(mdl);
    open_system(mdl);

    % Configure Model Solver settings
    set_param(mdl, 'SolverType', 'Fixed-step');
    set_param(mdl, 'Solver', 'FixedStepDiscrete');
    set_param(mdl, 'FixedStep', '1e-6');
    set_param(mdl, 'StopTime', '0.05');
    set_param(mdl, 'SaveOutput', 'on');
    set_param(mdl, 'OutputSaveName', 'yout');

    %% 1. Add Subsystems
    % Subsystem: Traffic Sources (Zones 1-3 + Attacks)
    trafficSubsys = [mdl, '/Traffic_and_Attack_Sources'];
    add_block('simulink/Ports & Subsystems/Subsystem', trafficSubsys, ...
        'Position', [50, 100, 250, 320]);

    % Subsystem: Defense Layer (IEEE 802.1Qci PSFP Policer)
    defenseSubsys = [mdl, '/IEEE_802_1Qci_Policing_Layer'];
    add_block('simulink/Ports & Subsystems/Subsystem', defenseSubsys, ...
        'Position', [330, 150, 520, 270]);

    % Subsystem: Zonal Gateway Switch Core
    switchSubsys = [mdl, '/Zonal_Gateway_Switch_Engine'];
    add_block('simulink/Ports & Subsystems/Subsystem', switchSubsys, ...
        'Position', [600, 120, 850, 300]);

    % Subsystem: Performance Analysis & Sinks
    sinksSubsys = [mdl, '/Performance_Monitors_and_Sinks'];
    add_block('simulink/Ports & Subsystems/Subsystem', sinksSubsys, ...
        'Position', [930, 130, 1150, 290]);

    %% 2. Populate Traffic & Attack Sources
    setup_traffic_subsystem(trafficSubsys);

    %% 3. Populate IEEE 802.1Qci Policer
    setup_defense_subsystem(defenseSubsys);

    %% 4. Populate Gateway Switch Engine
    setup_switch_subsystem(switchSubsys);

    %% 5. Populate Sinks
    setup_sinks_subsystem(sinksSubsys);

    %% 6. Top-Level Connections
    add_line(mdl, 'Traffic_and_Attack_Sources/1', 'Zonal_Gateway_Switch_Engine/1', 'autorouting', 'on'); % Crit traffic
    add_line(mdl, 'Traffic_and_Attack_Sources/2', 'IEEE_802_1Qci_Policing_Layer/1', 'autorouting', 'on'); % Best-effort traffic
    add_line(mdl, 'Traffic_and_Attack_Sources/3', 'IEEE_802_1Qci_Policing_Layer/2', 'autorouting', 'on'); % DoS attack
    add_line(mdl, 'Traffic_and_Attack_Sources/4', 'Zonal_Gateway_Switch_Engine/3', 'autorouting', 'on'); % Ransomware trigger

    add_line(mdl, 'IEEE_802_1Qci_Policing_Layer/1', 'Zonal_Gateway_Switch_Engine/2', 'autorouting', 'on'); % Policed BE/DoS traffic

    add_line(mdl, 'Zonal_Gateway_Switch_Engine/1', 'Performance_Monitors_and_Sinks/1', 'autorouting', 'on'); % Queue occupancy
    add_line(mdl, 'Zonal_Gateway_Switch_Engine/2', 'Performance_Monitors_and_Sinks/2', 'autorouting', 'on'); % Critical latency
    add_line(mdl, 'Zonal_Gateway_Switch_Engine/3', 'Performance_Monitors_and_Sinks/3', 'autorouting', 'on'); % Dropped bytes

    %% 7. Clean Layout and Save
    set_param(mdl, 'ZoomFactor', 'FitSystem');
    save_system(mdl, fullfile(pwd, [mdl, '.slx']));
    fprintf(' Successfully generated and saved: %s.slx\n', fullfile(pwd, mdl));
end

%% Helper: Setup Traffic and Attack Subsystem
function setup_traffic_subsystem(subsys)
    % Clean default contents
    delete_line(subsys, 'In1/1', 'Out1/1');
    delete_block([subsys, '/In1']);
    delete_block([subsys, '/Out1']);

    % Port 1: Critical Traffic (1 ms periodic pulses)
    add_block('simulink/Sources/Pulse Generator', [subsys, '/Critical_Control_Pulses'], ...
        'Period', '1000', 'PulseWidth', '1', 'Amplitude', '128', 'Position', [30, 40, 70, 70]);
    add_block('simulink/Ports & Subsystems/Outport', [subsys, '/Critical_Frames_Out'], ...
        'Position', [150, 45, 180, 65]);
    add_line(subsys, 'Critical_Control_Pulses/1', 'Critical_Frames_Out/1');

    % Port 2: Normal Best-Effort Baseline Traffic
    add_block('simulink/Sources/Constant', [subsys, '/Normal_BestEffort_Rate'], ...
        'Value', '15e6 / 8 * 1e-6', 'Position', [30, 110, 70, 140]); % Bytes per us
    add_block('simulink/Ports & Subsystems/Outport', [subsys, '/BestEffort_Frames_Out'], ...
        'Position', [150, 115, 180, 135]);
    add_line(subsys, 'Normal_BestEffort_Rate/1', 'BestEffort_Frames_Out/1');

    % Port 3: DoS Flood Attack (Starts at t=15ms, ends at t=35ms)
    add_block('simulink/Sources/Pulse Generator', [subsys, '/DoS_Flood_Generator'], ...
        'Period', '50000', 'PulseWidth', '20000', 'PhaseDelay', '15000', ...
        'Amplitude', '180e6 / 8 * 1e-6', 'Position', [30, 180, 70, 210]);
    add_block('simulink/Ports & Subsystems/Outport', [subsys, '/DoS_Flood_Out'], ...
        'Position', [150, 185, 180, 205]);
    add_line(subsys, 'DoS_Flood_Generator/1', 'DoS_Flood_Out/1');

    % Port 4: Ransomware Host Lockout (Step trigger at t=25ms)
    add_block('simulink/Sources/Step', [subsys, '/Ransomware_Trigger'], ...
        'Time', '0.025', 'Before', '0', 'After', '1', 'Position', [30, 250, 70, 280]);
    add_block('simulink/Ports & Subsystems/Outport', [subsys, '/Ransomware_State_Out'], ...
        'Position', [150, 255, 180, 275]);
    add_line(subsys, 'Ransomware_Trigger/1', 'Ransomware_State_Out/1');
end

%% Helper: Setup IEEE 802.1Qci Defense Subsystem
function setup_defense_subsystem(subsys)
    delete_line(subsys, 'In1/1', 'Out1/1');
    delete_block([subsys, '/In1']);
    delete_block([subsys, '/Out1']);

    add_block('simulink/Ports & Subsystems/Inport', [subsys, '/In_BestEffort'], 'Position', [30, 50, 60, 70]);
    add_block('simulink/Ports & Subsystems/Inport', [subsys, '/In_DoS_Flood'], 'Position', [30, 110, 60, 130]);

    % Combine best effort and attack
    add_block('simulink/Math Operations/Add', [subsys, '/Sum_BE_Traffic'], ...
        'Position', [100, 70, 130, 110]);
    add_line(subsys, 'In_BestEffort/1', 'Sum_BE_Traffic/1');
    add_line(subsys, 'In_DoS_Flood/1', 'Sum_BE_Traffic/2');

    % Token Bucket Saturation (IEEE 802.1Qci CIR policing limit: 25 Mbps = 3.125 bytes/us)
    add_block('simulink/Discontinuities/Saturation', [subsys, '/Ingress_Rate_Limiter'], ...
        'UpperLimit', '3.125', 'LowerLimit', '0', 'Position', [170, 75, 210, 105]);
    add_line(subsys, 'Sum_BE_Traffic/1', 'Ingress_Rate_Limiter/1');

    add_block('simulink/Ports & Subsystems/Outport', [subsys, '/Policed_BE_Out'], 'Position', [260, 80, 290, 100]);
    add_line(subsys, 'Ingress_Rate_Limiter/1', 'Policed_BE_Out/1');
end

%% Helper: Setup Gateway Switch Engine Subsystem
function setup_switch_subsystem(subsys)
    delete_line(subsys, 'In1/1', 'Out1/1');
    delete_block([subsys, '/In1']);
    delete_block([subsys, '/Out1']);

    add_block('simulink/Ports & Subsystems/Inport', [subsys, '/In_Crit_Bytes'], 'Position', [30, 40, 60, 60]);
    add_block('simulink/Ports & Subsystems/Inport', [subsys, '/In_BE_Bytes'], 'Position', [30, 90, 60, 110]);
    add_block('simulink/Ports & Subsystems/Inport', [subsys, '/In_Ransomware_Trigger'], 'Position', [30, 140, 60, 160]);

    % S-Function / MATLAB Function for Queue and Latency dynamics
    fcnBlock = [subsys, '/Gateway_Switch_Dynamics'];
    add_block('simulink/User-Defined Functions/MATLAB Function', fcnBlock, 'Position', [130, 60, 280, 150]);

    % Define core dynamics inside the MATLAB Function block
    sf = sfroot;
    m = sf.find('Path', fcnBlock, '-isa', 'Stateflow.EMChart');
    if ~isempty(m)
        m.Script = sprintf([...
            'function [queueKB, critLatUs, droppedBytes] = Gateway_Switch_Dynamics(critIn, beIn, ransomState)\n', ...
            '    persistent qBytes cumDrops;\n', ...
            '    if isempty(qBytes)\n', ...
            '        qBytes = 0;\n', ...
            '        cumDrops = 0;\n', ...
            '    end\n', ...
            '    \n', ...
            '    maxBuf = 32768; %% 32 KB buffer\n', ...
            '    linkRate = 12.5; %% 12.5 bytes per us (100 Mbps)\n', ...
            '    \n', ...
            '    %% Host degradation under Ransomware\n', ...
            '    if ransomState > 0.5\n', ...
            '        linkRate = linkRate * 0.5; %% 50%% CPU throttling\n', ...
            '        ransomPenaltyUs = 500;     %% 500 us cryptographic latency\n', ...
            '    else\n', ...
            '        ransomPenaltyUs = 0;\n', ...
            '    end\n', ...
            '    \n', ...
            '    totIn = critIn + beIn;\n', ...
            '    if (qBytes + totIn) <= maxBuf\n', ...
            '        qBytes = qBytes + totIn;\n', ...
            '    else\n', ...
            '        avail = max(0, maxBuf - qBytes);\n', ...
            '        if critIn <= avail\n', ...
            '            qBytes = qBytes + critIn;\n', ...
            '            dropped = totIn - critIn;\n', ...
            '        else\n', ...
            '            dropped = totIn;\n', ...
            '        end\n', ...
            '        cumDrops = cumDrops + dropped;\n', ...
            '    end\n', ...
            '    \n', ...
            '    served = min(qBytes, linkRate);\n', ...
            '    qBytes = qBytes - served;\n', ...
            '    \n', ...
            '    queueKB = qBytes / 1024;\n', ...
            '    critLatUs = (qBytes / linkRate) + ransomPenaltyUs;\n', ...
            '    droppedBytes = cumDrops;\n', ...
            'end\n']);
    end

    add_line(subsys, 'In_Crit_Bytes/1', 'Gateway_Switch_Dynamics/1');
    add_line(subsys, 'In_BE_Bytes/1', 'Gateway_Switch_Dynamics/2');
    add_line(subsys, 'In_Ransomware_Trigger/1', 'Gateway_Switch_Dynamics/3');

    add_block('simulink/Ports & Subsystems/Outport', [subsys, '/Out_Queue_KB'], 'Position', [340, 65, 370, 85]);
    add_block('simulink/Ports & Subsystems/Outport', [subsys, '/Out_Crit_Lat_us'], 'Position', [340, 95, 370, 115]);
    add_block('simulink/Ports & Subsystems/Outport', [subsys, '/Out_Dropped_Bytes'], 'Position', [340, 125, 370, 145]);

    add_line(subsys, 'Gateway_Switch_Dynamics/1', 'Out_Queue_KB/1');
    add_line(subsys, 'Gateway_Switch_Dynamics/2', 'Out_Crit_Lat_us/1');
    add_line(subsys, 'Gateway_Switch_Dynamics/3', 'Out_Dropped_Bytes/1');
end

%% Helper: Setup Performance Monitors and Sinks Subsystem
function setup_sinks_subsystem(subsys)
    delete_line(subsys, 'In1/1', 'Out1/1');
    delete_block([subsys, '/In1']);
    delete_block([subsys, '/Out1']);

    add_block('simulink/Ports & Subsystems/Inport', [subsys, '/In_Queue_KB'], 'Position', [30, 40, 60, 60]);
    add_block('simulink/Ports & Subsystems/Inport', [subsys, '/In_Crit_Lat_us'], 'Position', [30, 90, 60, 110]);
    add_block('simulink/Ports & Subsystems/Inport', [subsys, '/In_Dropped_Bytes'], 'Position', [30, 140, 60, 160]);

    % Scopes for visual monitoring
    add_block('simulink/Sinks/Scope', [subsys, '/Scope_Queue_KB'], 'Position', [140, 35, 180, 65]);
    add_block('simulink/Sinks/Scope', [subsys, '/Scope_Latency_us'], 'Position', [140, 85, 180, 115]);
    add_block('simulink/Sinks/Scope', [subsys, '/Scope_Drops'], 'Position', [140, 135, 180, 165]);

    % To Workspace blocks for post-simulation analysis
    add_block('simulink/Sinks/To Workspace', [subsys, '/ToWS_Queue'], ...
        'VariableName', 'sim_queueKB', 'SaveFormat', 'Array', 'Position', [220, 35, 280, 65]);
    add_block('simulink/Sinks/To Workspace', [subsys, '/ToWS_Latency'], ...
        'VariableName', 'sim_latUs', 'SaveFormat', 'Array', 'Position', [220, 85, 280, 115]);
    add_block('simulink/Sinks/To Workspace', [subsys, '/ToWS_Drops'], ...
        'VariableName', 'sim_drops', 'SaveFormat', 'Array', 'Position', [220, 135, 280, 165]);

    add_line(subsys, 'In_Queue_KB/1', 'Scope_Queue_KB/1');
    add_line(subsys, 'In_Queue_KB/1', 'ToWS_Queue/1');

    add_line(subsys, 'In_Crit_Lat_us/1', 'Scope_Latency_us/1');
    add_line(subsys, 'In_Crit_Lat_us/1', 'ToWS_Latency/1');

    add_line(subsys, 'In_Dropped_Bytes/1', 'Scope_Drops/1');
    add_line(subsys, 'In_Dropped_Bytes/1', 'ToWS_Drops/1');
end
