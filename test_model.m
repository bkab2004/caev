% Unit test script for Zonal Automotive Ethernet Gateway Model
% Verifies parameter loading, simulation core, and defensive policing logic.

function test_model()
    fprintf('Running tests for Zonal Gateway Model in D:\\caev ...\n');
    
    % 1. Test parameter loading
    cfg = parameters();
    assert(isfield(cfg, 'linkBandwidthBps'), 'Parameter linkBandwidthBps missing');
    assert(cfg.linkBandwidthBps == 100e6, 'Link bandwidth should be 100 Mbps');
    fprintf('  [PASS] Parameters validation\n');

    % 2. Test core simulation nominal case
    cfgNom = cfg;
    cfgNom.dos.enabled = false;
    cfgNom.ransom.enabled = false;
    resNom = zonal_gateway_core(cfgNom, false);
    assert(resNom.critLossRatio == 0, 'Nominal critical traffic must have zero loss');
    assert(resNom.deadlineViolations == 0, 'Nominal traffic must not violate 1ms deadline');
    fprintf('  [PASS] Nominal conditions deterministic delivery\n');

    % 3. Test DoS flood detection and policing
    cfgAttack = cfg;
    cfgAttack.dos.enabled = true;
    resProtected = zonal_gateway_core(cfgAttack, true);
    assert(resProtected.critLossRatio == 0, 'IEEE 802.1Qci must protect critical traffic from loss');
    assert(resProtected.beDropCount > 0, 'Policing must drop excess malicious traffic');
    fprintf('  [PASS] IEEE 802.1Qci stream policing effectiveness\n');

    fprintf('\nAll unit tests passed successfully!\n');
end
