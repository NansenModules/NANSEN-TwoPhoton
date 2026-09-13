classdef PixelCorrelationImageTest < matlab.unittest.TestCase
%PixelCorrelationImageTest Pixel-wise correlation images without the Statistics Toolbox
%
%   Tests nansen.module.twophoton.roi.compute.getPixelCorrelationImage on
%   a synthetic stack where one region follows the reference signal and
%   the rest is independent noise. When the Statistics and Machine
%   Learning Toolbox is available the correlations and p-values are also
%   compared against corr, which the function used to call.
%
%   Run tests:
%       runtests('twophotontest.PixelCorrelationImageTest')

    properties (Constant, Access = private)
        ImageSize = [6, 8]
        NumSamples = 60
    end

    methods (Access = private)
        function [signal, imChunk, followsSignal] = createStack(testCase)
            rng(7, 'twister')
            h = testCase.ImageSize(1); w = testCase.ImageSize(2); n = testCase.NumSamples;
            signal = cumsum(randn(n, 1));
            followsSignal = false(h, w);
            followsSignal(2:4, 2:5) = true;
            imChunk = randn(h, w, n);
            for iSample = 1:n
                frame = imChunk(:, :, iSample);
                frame(followsSignal) = 3*signal(iSample) + 0.1*randn(nnz(followsSignal), 1);
                imChunk(:, :, iSample) = frame;
            end
        end
    end

    methods (Test)

        function testRegionFollowingTheSignalCorrelates(testCase)
            [signal, imChunk, followsSignal] = testCase.createStack();
            [rhoIm, pIm] = nansen.module.twophoton.roi.compute.getPixelCorrelationImage(signal, imChunk);

            testCase.verifySize(rhoIm, testCase.ImageSize)
            testCase.verifyGreaterThan(rhoIm(followsSignal), 0.95)
            testCase.verifyLessThan(pIm(followsSignal), 1e-6)
            testCase.verifyLessThan(rhoIm(~followsSignal), 0.6)
            testCase.verifyGreaterThanOrEqual(rhoIm(:), 0)
        end

        function testConstantPixelsGiveZeroCorrelation(testCase)
            [signal, imChunk] = testCase.createStack();
            imChunk(1, 1, :) = 5;
            rhoIm = nansen.module.twophoton.roi.compute.getPixelCorrelationImage(signal, imChunk);
            testCase.verifyEqual(rhoIm(1, 1), 0)
        end

        function testMatchesStatisticsToolboxCorr(testCase)
            testCase.assumeTrue(exist('corr', 'file') == 2, ...
                'Statistics and Machine Learning Toolbox is not available')
            [signal, imChunk] = testCase.createStack();
            [rhoIm, pIm] = nansen.module.twophoton.roi.compute.getPixelCorrelationImage(signal, imChunk);

            pixelSignals = reshape(single(imChunk), [], testCase.NumSamples);
            [rhoExpected, pExpected] = corr(single(signal), pixelSignals', 'tail', 'right');
            rhoExpected = reshape(double(rhoExpected), testCase.ImageSize);
            rhoExpected(rhoExpected < 0) = 0.001;
            pExpected = reshape(double(pExpected), testCase.ImageSize);

            testCase.verifyEqual(rhoIm, rhoExpected, 'AbsTol', 1e-5)
            testCase.verifyEqual(pIm, pExpected, 'AbsTol', 1e-5)
        end
    end
end
