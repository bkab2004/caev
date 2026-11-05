% Zonal Automotive Ethernet Gateway Simulation Core
% Implements discrete-time simulation of gateway queue, attack profiles, and IEEE 802.1Qci defense.

function results = zonal_gateway_core(cfg, enableDefense)
    if nargin < 2
        enableDefense = cfg.defense.enabled;
    end

    dt = cfg.dt;
    timeVec = cfg.timeVec;
    numSteps = cfg.numSteps;
    linkCapBytesPerSec = cfg.linkCapacityBytesPerSec;
    maxBufBytes = cfg.maxQueueSizeBytes;

    % Token Bucket for IEEE 802.1Qci Policing
    tokenFillRate = cfg.defense.cirBps / 8; % bytes/sec
    tokenBucketCap = cfg.defense.cbsBytes;
    tokens = tokenBucketCap;

    % Queue State
    queueBytes = 0;

    % Pre-allocate diagnostic arrays
    queueOccupancyKB = zeros(1, numSteps);
    injectedRateMbps = zeros(1, numSteps);
    servedRateMbps   = zeros(1, numSteps);
    droppedBytesCum  = zeros(1, numSteps);

    critLatencies = [];
    critSendTimes = [];
    critDropCount = 0;
    critTotalCount = 0;

    beDropCount = 0;
    beTotalCount = 0;

    cumDroppedBytes = 0;

    for k = 1:numSteps
        t = timeVec(k);

        % 1. Replenish Token Bucket (IEEE 802.1Qci)
        if enableDefense
            tokens = min(tokenBucketCap, tokens + (tokenFillRate * dt));
        end

        % 2. Safety-Critical Control Traffic Ingestion (Class A / Strict Priority)
        isCritSent = any(abs(cfg.crit.sendTimes - t) < dt/2);
        critBytesIn = 0;
        if isCritSent
            critTotalCount = critTotalCount + 1;
            critBytesIn = cfg.crit.packetSize;
        end

        % 3. Sensor / Telemetry Ingestion (Class B)
        isSensorSent = any(abs(cfg.sensor.sendTimes - t) < dt/2);
        sensorBytesIn = 0;
        if isSensorSent
            sensorBytesIn = cfg.sensor.packetSize;
        end

        % 4. Best-Effort & DoS Flood Ingestion
        beRate = cfg.bestEffort.meanRateBps;
        isDosActive = cfg.dos.enabled && (t >= cfg.dos.startTime) && (t <= cfg.dos.endTime);
        if isDosActive
            beRate = beRate + cfg.dos.floodRateBps;
        end
        beBytesIn = (beRate / 8) * dt;
        beTotalCount = beTotalCount + (beBytesIn / cfg.bestEffort.packetSize);

        % 5. Ingress Policing (IEEE 802.1Qci PSFP)
        if enableDefense
            if beBytesIn <= tokens
                tokens = tokens - beBytesIn;
            else
                excessBytes = beBytesIn - tokens;
                beBytesIn = tokens;
                tokens = 0;
                beDropCount = beDropCount + (excessBytes / cfg.bestEffort.packetSize);
                cumDroppedBytes = cumDroppedBytes + excessBytes;
            end
        end

        % 6. Ingress to Gateway Switch Queue
        totalIncoming = critBytesIn + sensorBytesIn + beBytesIn;
        injectedRateMbps(k) = (totalIncoming * 8) / (dt * 1e6);

        % Buffer Admission Logic (Strict Priority Queuing)
        spaceAvailable = maxBufBytes - queueBytes;
        if totalIncoming <= spaceAvailable
            queueBytes = queueBytes + totalIncoming;
        else
            % Overflow condition
            if (critBytesIn + sensorBytesIn) <= spaceAvailable
                % Accept critical and sensor, drop best-effort/DoS
                acceptedHigh = critBytesIn + sensorBytesIn;
                queueBytes = queueBytes + acceptedHigh;
                droppedBE = totalIncoming - acceptedHigh;
                beDropCount = beDropCount + (droppedBE / cfg.bestEffort.packetSize);
                cumDroppedBytes = cumDroppedBytes + droppedBE;
            else
                % Severe congestion tail-drop affecting even critical frames
                critDropCount = critDropCount + 1;
                cumDroppedBytes = cumDroppedBytes + critBytesIn + sensorBytesIn + beBytesIn;
                beDropCount = beDropCount + (beBytesIn / cfg.bestEffort.packetSize);
            end
        end

        % 7. Gateway CPU Host Degradation (Ransomware Attack Modeling)
        isRansomActive = cfg.ransom.enabled && (t >= cfg.ransom.startTime);
        procPenalty = 0;
        effectiveCapacity = linkCapBytesPerSec;

        if isRansomActive
            % Malicious cryptographic process throttles gateway switching loop
            procPenalty = cfg.ransom.latencyPenalty;
            effectiveCapacity = effectiveCapacity * (1 - cfg.ransom.serviceThrottle);
        end

        % 8. Gateway Transmission / Packet Egress
        servedBytes = min(queueBytes, effectiveCapacity * dt);
        queueBytes = queueBytes - servedBytes;

        servedRateMbps(k) = (servedBytes * 8) / (dt * 1e6);
        queueOccupancyKB(k) = queueBytes / 1024;
        droppedBytesCum(k) = cumDroppedBytes;

        % 9. Track Latency for Critical Control Frames
        if isCritSent
            critSendTimes(end+1) = t; %#ok<AGROW>
            currentLatency = (queueBytes / linkCapBytesPerSec) + procPenalty;
            critLatencies(end+1) = currentLatency; %#ok<AGROW>
        end
    end

    % Compile Results
    results.timeVec = timeVec;
    results.queueOccupancyKB = queueOccupancyKB;
    results.injectedRateMbps = injectedRateMbps;
    results.servedRateMbps = servedRateMbps;
    results.droppedBytesCum = droppedBytesCum;

    results.critSendTimes = critSendTimes;
    results.critLatencies = critLatencies;
    results.critDropCount = critDropCount;
    results.critTotalCount = critTotalCount;
    results.critLossRatio = critDropCount / max(1, critTotalCount);

    results.beDropCount = beDropCount;
    results.beTotalCount = beTotalCount;
    results.beLossRatio = beDropCount / max(1, beTotalCount);

    % Deadline violations (> 1 ms latency)
    results.deadlineViolations = sum(critLatencies > cfg.crit.deadline);
end
