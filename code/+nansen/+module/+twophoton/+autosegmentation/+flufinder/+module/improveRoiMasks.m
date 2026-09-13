function roiArrayOut = improveRoiMasks(roiArrayIn, roiImageArray, roiType)
%improveRoiMasks Improve roi masks based on images of rois
%
%   roiArrayOut = improveRoiMasks(roiArrayIn, roiImageArray, roiType)
%   re-estimates each roi's mask from its image and drops rois whose
%   mask comes back empty. Per-roi statistics are not computed.

    import nansen.module.twophoton.autosegmentation.flufinder.binarize.getRoiMaskFromImage
    import nansen.module.twophoton.autosegmentation.flufinder.binarize.findSomaMaskByThresholding
    import nansen.module.twophoton.autosegmentation.flufinder.binarize.findSomaMaskByEdgeDetection

    if nargin < 3; roiType = 'soma'; end

    %params.roiDiameter = 12;
    roiDiameter = mean(2*sqrt([roiArrayIn.area]/pi));

    centerCoords = round(cat(1, roiArrayIn.center));

    fovSize = roiArrayIn(1).imagesize;
    blankFovMask = zeros(fovSize, 'logical');

    roiArrayOut = roiArrayIn;
    nRois = numel(roiArrayIn);

    keep = true(1, nRois);

    for i = 1:nRois

        roiImage = roiImageArray(:, :, i);

        switch lower( roiType )
            case 'axonal bouton'
                roiMaskSmall = getRoiMaskFromImage(roiImage, roiType, roiDiameter);

            case 'soma'
                % Todo: switch method
                % mask = findSomaMaskByThresholding(roiImage);
                roiMaskSmall = findSomaMaskByEdgeDetection(roiImage);

                %roiMaskSmall = nansen.module.twophoton.autosegmentation.flufinder.binarize.findSomaMaskByThresholding(roiImage);
        end

        % Skip roi if mask came back empty.
        if sum(roiMaskSmall)==0
            keep(i) = false;
            continue
        end

        % Expand roi mask to full fov size
        roiMask = nansen.module.twophoton.autosegmentation.flufinder.utility.placeLocalRoiMaskInFovMask(...
            roiMaskSmall, centerCoords(i, :), blankFovMask);

        roiArrayOut(i) = RoI('Mask', roiMask);
    end

    roiArrayOut = roiArrayOut(keep);
end
