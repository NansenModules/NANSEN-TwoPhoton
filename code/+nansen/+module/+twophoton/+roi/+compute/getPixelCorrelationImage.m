function [rhoIm, pIm] = getPixelCorrelationImage(signal, imChunk)
%getPixelCorrelationImage Correlate every pixel's time course with a signal
%
%   [rhoIm, pIm] = getPixelCorrelationImage(signal, imChunk) returns, for
%   the image stack imChunk (height-by-width-by-numSamples), the Pearson
%   correlation between each pixel's time course and signal
%   (numSamples-by-1) as an image rhoIm, and the right-tailed p-value of
%   each correlation as pIm. Negative correlations are floored at 0.001
%   and undefined ones (constant pixels) are set to 0, as the ROI image
%   consumers expect.
%
%   Computed without the Statistics and Machine Learning Toolbox: the
%   correlation is the normalised dot product of the centred time
%   courses, and the p-value follows from the t statistic through the
%   regularised incomplete beta function (the Student t distribution).

    imSize = size(imChunk);
    numSamples = imSize(3);

    % Make the imchunk into a matrix of nPixels x nSamples
    pixelSignals = reshape(imChunk, prod(imSize(1:2)), numSamples);

    % Make sure both data arrays are single
    pixelSignals = single(pixelSignals);
    signal = single(signal(:));

    % Pearson correlation of the signal with every pixel time course.
    signalCentered = signal - mean(signal);
    pixelsCentered = pixelSignals - mean(pixelSignals, 2);
    rho = (pixelsCentered * signalCentered) ./ ...
        (sqrt(sum(pixelsCentered.^2, 2)) .* sqrt(sum(signalCentered.^2)));

    % Right-tailed p-value of the correlation from its t statistic.
    degreesOfFreedom = numSamples - 2;
    tStatistic = rho .* sqrt(degreesOfFreedom ./ (1 - rho.^2));
    pValue = studentTRightTailProbability(double(tStatistic), degreesOfFreedom);

    rhoIm = reshape(double(rho), imSize(1), imSize(2));
    pIm = reshape(pValue, imSize(1), imSize(2));

    % To prevent negative values. Maybe this should be reconsidered...
    rhoIm(rhoIm<0)=0.001;

    % Remove nans
    rhoIm(isnan(rhoIm)) = 0;
end

function p = studentTRightTailProbability(t, degreesOfFreedom)
%studentTRightTailProbability P(T > t) for Student's t with the given dof
%
%   Uses the identity for the two-sided tail, 2*P(T > |t|) =
%   betainc(nu / (nu + t^2), nu/2, 1/2), and halves it on the right side.
    % An undefined correlation (constant time course) has no p-value; a
    % perfect one has t = +/-Inf and betainc(0, ...) = 0 handles it.
    p = nan(size(t));
    isDefined = ~isnan(t);
    twoSidedTail = betainc(degreesOfFreedom ./ (degreesOfFreedom + t(isDefined).^2), ...
        degreesOfFreedom/2, 0.5);
    p(isDefined) = twoSidedTail / 2;
    isNegative = isDefined & t < 0;
    p(isNegative) = 1 - p(isNegative);
end
