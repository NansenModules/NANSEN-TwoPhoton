function stats = getPixelMeasurements(im, roiMask)
%getPixelMeasurements Get pixel measurements from image based on mask

    roiBrightness = median(im(roiMask), 'omitnan');
    pilBrightness = median(im(~roiMask), 'omitnan');

    stats.dff = (roiBrightness-pilBrightness+1) ./ (pilBrightness+1);
    stats.val = roiBrightness;
end
