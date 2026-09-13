function [dec, den, opt] = deconvolveDff(dff, varargin)
%deconvolveDff Deconvolve dF/F signals with the selected method
%
%   [dec, den, opt] = deconvolveDff(dff) deconvolves dff, a numSamples x
%   numRois array as returned by computeDff, and returns the deconvolved
%   (dec) and denoised (den) signals in the same shape, plus the options
%   used (opt). A vector is treated as a single ROI in either orientation.
%
%   [dec, den, opt] = deconvolveDff(dff, Name, Value, ...) or
%   deconvolveDff(dff, options) sets the deconvolution parameters, see
%   getDeconvolutionParameters. The deconvolutionMethod parameter selects
%   a function from the process.deconvolve package by name.
%
%   P = deconvolveDff() returns the default parameters.
%
%   See also nansen.module.twophoton.roisignals.computeDff,
%   nansen.module.twophoton.roisignals.getDeconvolutionParameters

    [P, V] = nansen.module.twophoton.roisignals.getDeconvolutionParameters();
    P.deconvolutionMethod = 'caiman';

    if ~nargin
        dec = P; return
    end

    params = utility.parsenvpairs(P, V, varargin{:});

    deconvPackage = 'nansen.module.twophoton.roisignals.process.deconvolve';
    deconvFunction = str2func( strjoin({deconvPackage, params.deconvolutionMethod}, '.') );

    % The deconvolution methods want numRois x numSamples. The input
    % contract is numSamples x numRois (computeDff's output); a vector is
    % one ROI regardless of orientation. Shape is not guessed from which
    % dimension is larger, so recordings with more ROIs than samples are
    % deconvolved correctly.
    if isvector(dff)
        dffForMethod = reshape(dff, 1, []);
    else
        dffForMethod = transpose(dff);
    end

    [dec, den, opt] = deconvFunction(dffForMethod, params);

    dec = reshape(transpose(dec), size(dff));
    den = reshape(transpose(den), size(dff));
end
