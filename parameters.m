% Parameters for Zonal Automotive Ethernet Gateway Attack Simulation
% Architecture: Zonal Gateway (ZGW) connecting CAN-FD/LIN to 100BASE-T1 Ethernet

function cfg = parameters()
    %% 1. Simulation Timing
    cfg.simTime = 0.050;                % 50 ms simulation window
    cfg.dt = 1e-6;                      % 1 microsecond resolution (1 MHz sampling)
    cfg.timeVec = 0:cfg.dt:cfg.simTime;
    cfg.numSteps = length(cfg.timeVec);

    %% 2. Automotive Ethernet Link & Gateway Hardware Parameters
    cfg.linkBandwidthBps = 100e6;       % 100BASE-T1 link (100 Mbps)
    cfg.linkCapacityBytesPerSec = cfg.linkBandwidthBps / 8; % 12.5 MB/s
    cfg.maxQueueSizeBytes = 32 * 1024;  % 32 KB switch buffer memory
    cfg.maxQueuePackets = 128;          % Max queue depth in frames

    %% 3. Traffic Profiles (Normal Operating Conditions)
    % Stream 1: Safety-Critical ADAS/Chassis (Time-Triggered, ASIL-D)
    cfg.crit.period = 0.001;            % 1 ms periodic transmission
    cfg.crit.packetSize = 128;          % 128 bytes per frame (SOME/IP payload)
    cfg.crit.deadline = 0.001;          % 1 ms maximum allowable end-to-end latency
    cfg.crit.sendTimes = 0:cfg.crit.period:cfg.simTime;

    % Stream 2: High-Rate Telemetry / Sensor Stream (Camera/Radar metadata)
    cfg.sensor.period = 0.002;          % 2 ms period
    cfg.sensor.packetSize = 512;        % 512 bytes
    cfg.sensor.sendTimes = 0:cfg.sensor.period:cfg.simTime;

    % Stream 3: Best-Effort In-Vehicle Diagnostics (DoIP / Infotainment)
    cfg.bestEffort.meanRateBps = 15e6;  % 15 Mbps baseline bandwidth
    cfg.bestEffort.packetSize = 1024;   % 1024 bytes

    %% 4. Attack Scenarios
    % Attack Vector 1: Denial of Service (DoS) Flood
    cfg.dos.enabled = true;
    cfg.dos.startTime = 0.015;          % Starts at 15 ms
    cfg.dos.endTime = 0.035;            % Ends at 35 ms
    cfg.dos.floodRateBps = 180e6;       % 180 Mbps (180% of port capacity)
    cfg.dos.packetSize = 1024;          % 1024 bytes per malicious frame

    % Attack Vector 2: Ransomware Host Starvation
    % Emulates malicious background cryptographic routines consuming gateway CPU
    cfg.ransom.enabled = true;
    cfg.ransom.startTime = 0.025;       % Ransomware crypto lockup starts at 25 ms
    cfg.ransom.latencyPenalty = 500e-6; % 500 us gateway forwarding delay penalty
    cfg.ransom.serviceThrottle = 0.50;  % 50% reduction in switch forwarding rate

    %% 5. Defense: IEEE 802.1Qci (Per-Stream Filtering & Policing - PSFP)
    cfg.defense.enabled = true;
    cfg.defense.cirBps = 25e6;          % Committed Information Rate: 25 Mbps
    cfg.defense.cbsBytes = 4096;        % Committed Burst Size: 4 KB token bucket
end
