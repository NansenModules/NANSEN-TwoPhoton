classdef SciScanRawFileTest < matlab.unittest.TestCase
%SciScanRawFileTest Reading SciScan .raw recordings and their .ini files
%
%   Tests nansen.module.twophoton.io.sciscan.readrawfile and readinivar
%   on synthetic recordings written by the test: a small big-endian .raw
%   file with one block per channel per frame, and an .ini file with the
%   variables the reader consults. The layout follows what the reader
%   has always assumed (x fastest, channel blocks per frame), so the
%   fixture is written with plain fwrite rather than through the reader.
%
%   Run tests:
%       runtests('twophotontest.SciScanRawFileTest')

    properties (Constant, Access = private)
        Width = 4
        Height = 3
        NumChannels = 2
        NumFrames = 5
    end

    methods (Access = private)

        function [rawPath, expected] = createRecording(testCase, sampleType)
        %createRecording Write a .raw/.ini pair; expected is x-by-y-by-frames-by-channels
            arguments
                testCase
                sampleType (1,1) string = "uint16"
            end
            import matlab.unittest.fixtures.TemporaryFolderFixture
            folderPath = char(testCase.applyFixture(TemporaryFolderFixture).Folder);
            baseName = '20200101_12_00_00_recording';
            rawPath = fullfile(folderPath, [baseName, '.raw']);

            [w, h, c, f] = deal(testCase.Width, testCase.Height, testCase.NumChannels, testCase.NumFrames);
            expected = zeros(w, h, f, c, sampleType);
            for iFrame = 1:f
                for iChannel = 1:c
                    block = iFrame*100 + iChannel*10 + reshape(1:w*h, w, h);
                    expected(:, :, iFrame, iChannel) = cast(block, sampleType);
                end
            end

            if sampleType == "uint16"
                fileFormat = 0; sourceType = 'uint16';
            else
                fileFormat = 1; sourceType = 'float32';
            end

            fileId = fopen(rawPath, 'w', 'b');
            testCase.assertNotEqual(fileId, -1)
            % File order: frame, then channel, then y, then x (x fastest).
            fwrite(fileId, permute(expected, [1, 2, 4, 3]), sourceType);
            fclose(fileId);

            iniText = sprintf([ ...
                '[_Recording]\n', ...
                'x.pixels = %d\n', ...
                'y.pixels = %d\n', ...
                'no.of.frames.acquired = %d\n', ...
                'file.format = %d\n', ...
                'save.ch.0 = TRUE\n', ...
                'save.ch.1 = TRUE\n', ...
                'save.ch.2 = FALSE\n', ...
                'frames.p.sec = "30,9"\n', ...
                'experiment.type = "XYT"\n'], w, h, f, fileFormat);
            fileId = fopen(fullfile(folderPath, [baseName, '.ini']), 'w');
            testCase.assertNotEqual(fileId, -1)
            fwrite(fileId, iniText, 'char');
            fclose(fileId);
        end

        function data = read(~, rawPath, varargin)
            data = nansen.module.twophoton.io.sciscan.readrawfile(rawPath, varargin{:});
        end
    end

    methods (Test)

        function testAllChannelsAreReadInFileOrder(testCase)
            [rawPath, expected] = testCase.createRecording();
            data = testCase.read(rawPath);
            testCase.verifyClass(data, 'uint16')
            testCase.verifySize(data, [testCase.Width, testCase.Height, testCase.NumFrames, testCase.NumChannels])
            testCase.verifyEqual(data, expected)
        end

        function testOneChannelIsRead(testCase)
            [rawPath, expected] = testCase.createRecording();
            data = testCase.read(rawPath, 'Channel', 2);
            testCase.verifySize(data, [testCase.Width, testCase.Height, testCase.NumFrames])
            testCase.verifyEqual(data, expected(:, :, :, 2))
        end

        function testSkipAndCountSelectFrames(testCase)
            [rawPath, expected] = testCase.createRecording();
            data = testCase.read(rawPath, 'Channel', 1, 'SkipFrames', 2, 'NumFrames', 2);
            testCase.verifyEqual(data, expected(:, :, 3:4, 1))

            dataAll = testCase.read(rawPath, 'SkipFrames', 4);
            testCase.verifyEqual(dataAll, expected(:, :, 5, :))
        end

        function testRequestingTooManyFramesWarnsAndTruncates(testCase)
            [rawPath, expected] = testCase.createRecording();
            data = testCase.verifyWarning( ...
                @() testCase.read(rawPath, 'Channel', 1, 'SkipFrames', 3, 'NumFrames', 10), ...
                'NANSEN:TwoPhoton:SciScan:FewerFramesThanRequested');
            testCase.verifyEqual(data, expected(:, :, 4:5, 1))
        end

        function testSingleSampleTypeIsRead(testCase)
            [rawPath, expected] = testCase.createRecording("single");
            data = testCase.read(rawPath);
            testCase.verifyClass(data, 'single')
            testCase.verifyEqual(data, expected)
        end

        function testInvalidChannelErrors(testCase)
            rawPath = testCase.createRecording();
            testCase.verifyError(@() testCase.read(rawPath, 'Channel', 3), ...
                'NANSEN:TwoPhoton:SciScan:InvalidChannel')
        end

        function testMissingIniFileErrors(testCase)
            rawPath = testCase.createRecording();
            delete(fullfile(fileparts(rawPath), '*.ini'))
            testCase.verifyError(@() testCase.read(rawPath), ...
                'NANSEN:TwoPhoton:SciScan:IniFileNotFound')
        end

        function testIniVariablesAreTyped(testCase)
            import nansen.module.twophoton.io.sciscan.readinivar
            rawPath = testCase.createRecording();
            iniText = fileread(fullfile(fileparts(rawPath), '20200101_12_00_00_recording.ini'));

            testCase.verifyEqual(readinivar(iniText, 'x.pixels'), 4)
            testCase.verifyEqual(readinivar(iniText, 'save.ch.0'), true)
            testCase.verifyEqual(readinivar(iniText, 'save.ch.2'), false)
            testCase.verifyEqual(readinivar(iniText, 'frames.p.sec'), 30.9)
            testCase.verifyEqual(readinivar(iniText, 'experiment.type'), 'XYT')
            testCase.verifyEmpty(readinivar(iniText, 'not.there'))
        end

        function testIniLookupMatchesWholeNames(testCase)
            import nansen.module.twophoton.io.sciscan.readinivar
            % "x.pixels" must not match "max.pixels" or "x.pixels.extra".
            iniText = sprintf('max.pixels = 99\nx.pixels.extra = 7\nx.pixels = 4\n');
            testCase.verifyEqual(readinivar(iniText, 'x.pixels'), 4)
        end
    end
end
