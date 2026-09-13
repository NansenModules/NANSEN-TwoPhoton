function value = readinivar(iniText, variableName)
%readinivar Read one variable from the text of a SciScan .ini file
%
%   value = readinivar(iniText, variableName) finds the line of iniText
%   that assigns variableName and returns its value: TRUE/FALSE as a
%   logical, a number (a "," decimal separator is accepted) as a double,
%   and any other text as a character vector without its surrounding
%   quotes. Returns [] when the variable is not present.
%
%   The .ini file is plain text; nothing in it is evaluated as code.

    arguments
        iniText (1,:) char
        variableName (1,:) char
    end

    % One line: the name at the start of a line, "=", then the rest of
    % that line. lineanchors makes ^ match after every newline.
    pattern = ['^[ \t]*', regexptranslate('escape', variableName), '[ \t]*=([^\r\n]*)'];
    match = regexp(iniText, pattern, 'tokens', 'once', 'lineanchors');

    if isempty(match)
        value = [];
        return
    end

    text = strtrim(match{1});
    text = strtrim(strrep(text, '"', ''));

    if strcmpi(text, 'TRUE')
        value = true;
    elseif strcmpi(text, 'FALSE')
        value = false;
    else
        numberValue = str2double(strrep(text, ',', '.'));
        if isnan(numberValue)
            value = text;
        else
            value = numberValue;
        end
    end
end
