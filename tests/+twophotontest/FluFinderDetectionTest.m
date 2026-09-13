classdef FluFinderDetectionTest < matlab.unittest.TestCase
%FluFinderDetectionTest FluFinder's component picking on small inputs
%
%   Exercises nansen.module.twophoton.autosegmentation.flufinder.detect.
%   findUniqueRoisFromComponents with hand-built component stats, the
%   struct array that getBwComponentStats returns (Area, Centroid,
%   PixelIdxList). Covers the degenerate inputs that used to error in
%   histcounts or spin forever: no components, and a single repeated
%   component.
%
%   Run tests:
%       runtests('twophotontest.FluFinderDetectionTest')

    properties (Constant, Access = private)
        ImageSize = [48, 48]
    end

    methods (Access = private)

        function S = createComponents(testCase, center, radius, numObservations)
        %createComponents The same disk observed numObservations times
            [columns, rows] = meshgrid(1:testCase.ImageSize(2), 1:testCase.ImageSize(1));
            mask = (columns - center(1)).^2 + (rows - center(2)).^2 <= radius^2;
            pixelIndices = find(mask);
            S = repmat(struct('Area', numel(pixelIndices), 'Centroid', center, ...
                'PixelIdxList', pixelIndices), numObservations, 1);
        end

        function rois = findRois(testCase, S)
            rois = nansen.module.twophoton.autosegmentation.flufinder.detect. ...
                findUniqueRoisFromComponents(testCase.ImageSize, S);
        end
    end

    methods (Test)

        function testNoComponentsGivesNoRois(testCase)
            S = struct('Area', {}, 'Centroid', {}, 'PixelIdxList', {});
            rois = testCase.findRois(S);
            testCase.verifyClass(rois, 'RoI')
            testCase.verifyEmpty(rois)
        end

        function testRepeatedComponentGivesOneRoi(testCase)
            S = testCase.createComponents([20, 24], 5, 3);
            rois = testCase.findRois(S);
            testCase.verifyClass(rois, 'RoI')
            testCase.verifyNumElements(rois, 1)
        end

        function testTwoSeparatedComponentsGiveTwoRois(testCase)
            S = [testCase.createComponents([14, 14], 5, 3); ...
                 testCase.createComponents([34, 34], 5, 3)];
            rois = testCase.findRois(S);
            testCase.verifyNumElements(rois, 2)
        end
    end
end
