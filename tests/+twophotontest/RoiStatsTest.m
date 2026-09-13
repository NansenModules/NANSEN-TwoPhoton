classdef RoiStatsTest < matlab.unittest.TestCase
%RoiStatsTest Statistics computed from ROI dF/F traces
%
%   Tests the parts of nansen.module.twophoton.roi.stats.dffprops that
%   run without the Signal Processing Toolbox (the SNR fields need it).
%   The skewness is checked against its definition and, when the
%   Statistics and Machine Learning Toolbox is present, against skewness.
%
%   Run tests:
%       runtests('twophotontest.RoiStatsTest')

    methods (Access = private)
        function dff = createDff(~)
            rng(3, 'twister')
            numSamples = 300;
            dff = 0.05*randn(numSamples, 3);
            dff(20:40, 1) = dff(20:40, 1) + 1;          % one large transient: right skew
            dff(:, 3) = -dff(:, 1);                     % mirrored: left skew
        end
    end

    methods (Test)

        function testSkewnessSignAndShape(testCase)
            dff = testCase.createDff();
            stats = nansen.module.twophoton.roi.stats.dffprops(dff, 'DffSkewness');

            testCase.verifySize(stats.DffSkewness, [3, 1])
            testCase.verifyGreaterThan(stats.DffSkewness(1), 1)
            testCase.verifyLessThan(abs(stats.DffSkewness(2)), 0.5)
            testCase.verifyEqual(stats.DffSkewness(3), -stats.DffSkewness(1), 'AbsTol', 1e-12)
        end

        function testSkewnessMatchesTheDefinition(testCase)
            dff = testCase.createDff();
            stats = nansen.module.twophoton.roi.stats.dffprops(dff, 'DffSkewness');
            centered = dff - mean(dff, 1);
            expected = (mean(centered.^3, 1) ./ std(dff, 1, 1).^3)';
            testCase.verifyEqual(stats.DffSkewness, expected, 'AbsTol', 1e-12)
        end

        function testSkewnessMatchesStatisticsToolbox(testCase)
            testCase.assumeTrue(exist('skewness', 'file') == 2, ...
                'Statistics and Machine Learning Toolbox is not available')
            dff = testCase.createDff();
            stats = nansen.module.twophoton.roi.stats.dffprops(dff, 'DffSkewness');
            testCase.verifyEqual(stats.DffSkewness, skewness(dff, 1, 1)', 'AbsTol', 1e-12)
        end

        function testPeakIsPerRoi(testCase)
            dff = testCase.createDff();
            stats = nansen.module.twophoton.roi.stats.dffprops(dff, 'DffPeak');
            testCase.verifyEqual(stats.DffPeak, max(dff, [], 1)')
        end

        function testOnlyRequestedFieldsAreReturned(testCase)
            % Both documented call forms must select fields; neither may
            % compute the noise level, which needs the Signal Processing
            % Toolbox, when only peak and skewness are asked for.
            dff = testCase.createDff();
            positional = nansen.module.twophoton.roi.stats.dffprops(dff, 'DffPeak', 'DffSkewness');
            nameValue = nansen.module.twophoton.roi.stats.dffprops(dff, 'Properties', {'DffPeak', 'DffSkewness'});
            testCase.verifyEqual(sort(fieldnames(positional)), {'DffPeak'; 'DffSkewness'})
            testCase.verifyEqual(positional, nameValue)
        end

        function testNoiseBasedFieldsNeedTheSignalProcessingToolbox(testCase)
            dff = testCase.createDff();
            if exist('pwelch', 'file') == 2
                stats = nansen.module.twophoton.roi.stats.dffprops(dff, 'DffActivityLevel');
                testCase.verifySize(stats.DffActivityLevel, [3, 1])
            else
                testCase.verifyError( ...
                    @() nansen.module.twophoton.roi.stats.dffprops(dff, 'DffActivityLevel'), ...
                    'NANSEN:TwoPhoton:SignalProcessingToolboxRequired')
            end
        end
    end
end
