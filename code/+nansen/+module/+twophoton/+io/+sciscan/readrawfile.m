function data = readrawfile(filePath, options)
%readrawfile Read image frames from a SciScan .raw recording file
%
%   data = readrawfile(filePath) reads every frame of every recorded
%   channel from the .raw file at filePath. The layout of the file comes
%   from the .ini file with the same name next to it: image size
%   (x.pixels, y.pixels), sample type (file.format: 0 for uint16, 1 for
%   single) and the recorded channels (save.ch.N or ai.activeN). Samples
%   are stored big-endian, x fastest, one x-by-y block per channel for
%   each frame.
%
%   data has size x-by-y-by-numFrames-by-numChannels in the sample type
%   of the file, and x-by-y-by-numFrames when one channel is requested.
%
%   data = readrawfile(filePath, Name, Value) selects what to read:
%       Channel    - "all" (default), or the 1-based number of one channel
%       SkipFrames - number of frames to skip at the start (default 0)
%       NumFrames  - number of frames to read after the skipped ones
%                    (default: all that remain). If fewer are present the
%                    available frames are returned with a warning.
%
%   See also nansen.module.twophoton.io.sciscan.readinivar,
%   nansen.module.twophoton.io.sciscan.SciScanRaw

    arguments
        filePath (1,1) string {mustBeFile}
        options.Channel = "all"
        options.SkipFrames (1,1) double {mustBeInteger, mustBeNonnegative} = 0
        options.NumFrames double {mustBeScalarOrEmpty, mustBeInteger, mustBeNonnegative} = []
    end

    layout = readFileLayout(filePath);
    channelIndex = validateChannel(options.Channel, layout.NumChannels);
    readAllChannels = isempty(channelIndex);

    samplesPerBlock = layout.Width * layout.Height;
    bytesPerBlock = samplesPerBlock * layout.BytesPerSample;
    bytesPerFrame = bytesPerBlock * layout.NumChannels;

    fileInfo = dir(filePath);
    numFramesAvailable = max(0, floor(fileInfo.bytes / bytesPerFrame) - options.SkipFrames);
    if isempty(options.NumFrames)
        numFrames = numFramesAvailable;
    else
        numFrames = options.NumFrames;
        if numFrames > numFramesAvailable
            warning('NANSEN:TwoPhoton:SciScan:FewerFramesThanRequested', ...
                ['Requested %d frames of "%s" but only %d are available ', ...
                 'after skipping %d; reading %d.'], numFrames, filePath, ...
                numFramesAvailable, options.SkipFrames, numFramesAvailable)
            numFrames = numFramesAvailable;
        end
    end

    precision = sprintf('%s=>%s', layout.SourceType, layout.SampleType);
    fileId = fopen(filePath, 'r', 'b');
    if fileId == -1
        error('NANSEN:TwoPhoton:SciScan:CannotOpenFile', 'Could not open "%s".', filePath)
    end
    fileCleanup = onCleanup(@() fclose(fileId));

    if readAllChannels
        fseek(fileId, options.SkipFrames * bytesPerFrame, 'bof');
        data = fread(fileId, [samplesPerBlock * layout.NumChannels, numFrames], precision);
        expectedSize = [layout.Width, layout.Height, layout.NumChannels, numFrames];
        assertNumberOfSamples(data, expectedSize, filePath)
        data = permute(reshape(data, expectedSize), [1, 2, 4, 3]);
    else
        % Read one block per frame and skip the other channels' blocks.
        fseek(fileId, options.SkipFrames * bytesPerFrame + (channelIndex - 1) * bytesPerBlock, 'bof');
        blockPrecision = sprintf('%d*%s', samplesPerBlock, precision);
        skipBytes = (layout.NumChannels - 1) * bytesPerBlock;
        data = fread(fileId, [samplesPerBlock, numFrames], blockPrecision, skipBytes);
        expectedSize = [layout.Width, layout.Height, numFrames];
        assertNumberOfSamples(data, expectedSize, filePath)
        data = reshape(data, expectedSize);
    end
end

function layout = readFileLayout(filePath)
%readFileLayout Image size, sample type and channel count from the .ini file
    import nansen.module.twophoton.io.sciscan.readinivar

    [folderPath, baseName] = fileparts(filePath);
    iniPath = fullfile(folderPath, baseName + ".ini");
    if ~isfile(iniPath)
        error('NANSEN:TwoPhoton:SciScan:IniFileNotFound', ...
            'The .ini file describing "%s" was not found next to it.', filePath)
    end
    iniText = fileread(iniPath);

    layout.Width = requireNumber(readinivar(iniText, 'x.pixels'), 'x.pixels', iniPath);
    layout.Height = requireNumber(readinivar(iniText, 'y.pixels'), 'y.pixels', iniPath);

    fileFormat = requireNumber(readinivar(iniText, 'file.format'), 'file.format', iniPath);
    switch fileFormat
        case 0
            layout.SourceType = 'uint16';
            layout.SampleType = 'uint16';
            layout.BytesPerSample = 2;
        case 1
            layout.SourceType = 'float32';
            layout.SampleType = 'single';
            layout.BytesPerSample = 4;
        otherwise
            error('NANSEN:TwoPhoton:SciScan:UnsupportedFileFormat', ...
                'file.format %g in "%s" is not supported (0 = uint16, 1 = single).', ...
                fileFormat, iniPath)
    end

    layout.NumChannels = countRecordedChannels(iniText);
    if layout.NumChannels == 0
        error('NANSEN:TwoPhoton:SciScan:NoRecordedChannels', ...
            'No recorded channel (save.ch.N or ai.activeN) is marked TRUE in "%s".', iniPath)
    end
end

function numChannels = countRecordedChannels(iniText)
%countRecordedChannels Channels flagged save.ch.N or ai.activeN in the .ini
    import nansen.module.twophoton.io.sciscan.readinivar

    numChannels = 0;
    for iChannel = 0:5
        isSaved = readinivar(iniText, sprintf('save.ch.%d', iChannel));
        isActive = readinivar(iniText, sprintf('ai.active%d', iChannel));
        if isequal(isSaved, true) || isequal(isActive, true)
            numChannels = numChannels + 1;
        end
    end
end

function value = requireNumber(value, variableName, iniPath)
    if ~(isnumeric(value) && isscalar(value))
        error('NANSEN:TwoPhoton:SciScan:MissingIniVariable', ...
            'The variable "%s" is missing or not a number in "%s".', variableName, iniPath)
    end
end

function channelIndex = validateChannel(channel, numChannels)
%validateChannel [] for all channels, otherwise the validated channel index
    if (isstring(channel) || ischar(channel)) && strcmpi(channel, "all")
        channelIndex = [];
        return
    end
    isValidIndex = isnumeric(channel) && isscalar(channel) ...
        && channel == round(channel) && channel >= 1 && channel <= numChannels;
    if ~isValidIndex
        error('NANSEN:TwoPhoton:SciScan:InvalidChannel', ...
            'Channel must be "all" or an integer between 1 and %d.', numChannels)
    end
    channelIndex = channel;
end

function assertNumberOfSamples(data, expectedSize, filePath)
    if numel(data) ~= prod(expectedSize)
        error('NANSEN:TwoPhoton:SciScan:TruncatedFile', ...
            '"%s" ended before the requested frames could be read.', filePath)
    end
end
