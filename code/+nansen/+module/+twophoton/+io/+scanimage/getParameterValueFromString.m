function value = getParameterValueFromString(parameterString)
%getParameterValueFromString Parse the value of a ScanImage header parameter
%
%   value = getParameterValueFromString(parameterString) takes one line of
%   ScanImage TIFF metadata of the form "SI.some.parameter = <value>" and
%   returns the value as a MATLAB value.
%
%   The value grammar is the subset of MATLAB literal syntax ScanImage
%   writes: numbers (including NaN and Inf), single-quoted strings, true
%   and false, bracketed numeric or logical arrays with ";" between rows,
%   brace-delimited cell arrays of those, and zeros/ones/nan/true/false
%   size constructors such as zeros(1,0). Anything else is returned as a
%   character vector together with a warning; header text is data and is
%   never executed as code.
%
%   An empty value returns [] with a warning.

    arguments
        parameterString (1,:) char
    end

    separatorIndex = find(parameterString == '=', 1, 'first');
    if isempty(separatorIndex)
        error('NANSEN:TwoPhoton:ScanImage:InvalidParameterString', ...
            'Expected a "name = value" line, got "%s".', parameterString)
    end
    parameterName = strtrim(parameterString(1:separatorIndex-1));
    valueText = strtrim(parameterString(separatorIndex+1:end));

    if isempty(valueText)
        warning('NANSEN:TwoPhoton:ScanImage:EmptyParameterValue', ...
            'No value was found for parameter "%s".', parameterName)
        value = [];
        return
    end

    [value, wasParsed] = parseLiteral(valueText);
    if ~wasParsed
        warning('NANSEN:TwoPhoton:ScanImage:UnparsedParameterValue', ...
            ['The value of parameter "%s" ("%s") is not a recognised ', ...
             'literal and is returned as text.'], parameterName, valueText)
        value = valueText;
    end
end

function [value, wasParsed] = parseLiteral(text)
%parseLiteral Parse one literal; wasParsed is false for unknown syntax
    text = strtrim(text);
    if isempty(text)
        value = [];
        wasParsed = false;
    elseif text(1) == ''''
        [value, wasParsed] = parseQuotedString(text);
    elseif text(1) == '['
        [value, wasParsed] = parseBracketedArray(text);
    elseif text(1) == '{'
        [value, wasParsed] = parseCellArray(text);
    elseif any(strcmpi(text, {'true', 'false'}))
        value = strcmpi(text, 'true');
        wasParsed = true;
    else
        [value, wasParsed] = parseNumberOrSizeConstructor(text);
    end
end

function [value, wasParsed] = parseQuotedString(text)
%parseQuotedString 'text' with '' as the escaped quote
    wasParsed = numel(text) >= 2 && text(end) == '''';
    if wasParsed
        value = strrep(text(2:end-1), '''''', '''');
    else
        value = [];
    end
end

function [value, wasParsed] = parseNumberOrSizeConstructor(text)
%parseNumberOrSizeConstructor A number, or zeros/ones/nan/true/false(size)
    value = [];
    wasParsed = false;

    numberValue = str2double(text);
    if ~isnan(numberValue) || strcmpi(text, 'nan')
        value = numberValue;
        wasParsed = true;
        return
    end

    tokens = regexp(text, '^(zeros|ones|nan|true|false)\s*\(([\d\s,]*)\)$', ...
        'tokens', 'once', 'ignorecase');
    if isempty(tokens)
        return
    end

    sizeText = regexp(tokens{2}, '\d+', 'match');
    sizeArguments = str2double(sizeText);
    if any(isnan(sizeArguments))
        return
    end
    if isempty(sizeArguments)
        sizeArguments = 1;
    end

    switch lower(tokens{1})
        case 'zeros'
            value = zeros(sizeArguments);
        case 'ones'
            value = ones(sizeArguments);
        case 'nan'
            value = nan(sizeArguments);
        case 'true'
            value = true(sizeArguments);
        case 'false'
            value = false(sizeArguments);
        otherwise
            return % The pattern above admits no other names.
    end
    wasParsed = true;
end

function [value, wasParsed] = parseBracketedArray(text)
%parseBracketedArray [a b; c d] of numbers or logicals
    value = [];
    wasParsed = false;
    if text(end) ~= ']'
        return
    end

    [rows, isBalanced] = splitTopLevel(text(2:end-1));
    if ~isBalanced
        return
    end
    if isempty(rows)
        value = [];
        wasParsed = true;
        return
    end

    rowValues = cell(1, numel(rows));
    for iRow = 1:numel(rows)
        elements = rows{iRow};
        elementValues = cell(1, numel(elements));
        for iElement = 1:numel(elements)
            [elementValue, elementParsed] = parseLiteral(elements{iElement});
            isScalarLiteral = elementParsed && (isnumeric(elementValue) || islogical(elementValue)) ...
                && isscalar(elementValue);
            if ~isScalarLiteral
                return
            end
            elementValues{iElement} = elementValue;
        end
        rowValues{iRow} = [elementValues{:}];
    end

    rowLengths = cellfun(@numel, rowValues);
    if any(rowLengths ~= rowLengths(1))
        return
    end
    value = vertcat(rowValues{:});
    if ~all(cellfun(@islogical, rowValues))
        value = double(value);
    end
    wasParsed = true;
end

function [value, wasParsed] = parseCellArray(text)
%parseCellArray {a b; c d} of any literal
    value = {};
    wasParsed = false;
    if text(end) ~= '}'
        return
    end

    [rows, isBalanced] = splitTopLevel(text(2:end-1));
    if ~isBalanced
        return
    end
    if isempty(rows)
        wasParsed = true;
        return
    end

    rowLengths = cellfun(@numel, rows);
    if any(rowLengths ~= rowLengths(1))
        return
    end

    value = cell(numel(rows), rowLengths(1));
    for iRow = 1:numel(rows)
        for iElement = 1:rowLengths(1)
            [value{iRow, iElement}, elementParsed] = parseLiteral(rows{iRow}{iElement});
            if ~elementParsed
                value = {};
                return
            end
        end
    end
    wasParsed = true;
end

function [rows, isBalanced] = splitTopLevel(text)
%splitTopLevel Split on top-level separators: whitespace/"," between
%   elements and ";"/newline between rows. Brackets, braces and quotes
%   nest, so "{[1 2] 'a b'}" yields one row with two elements.
    rows = {};
    currentRow = {};
    token = '';
    depth = 0;
    inQuote = false;

    for character = text
        if inQuote
            token(end+1) = character; %#ok<AGROW>
            if character == ''''
                inQuote = false;
            end
        elseif character == ''''
            inQuote = true;
            token(end+1) = character; %#ok<AGROW>
        elseif any(character == '[{')
            depth = depth + 1;
            token(end+1) = character; %#ok<AGROW>
        elseif any(character == ']}')
            depth = depth - 1;
            token(end+1) = character; %#ok<AGROW>
        elseif depth == 0 && (character == ';' || character == newline)
            [currentRow, token] = closeToken(currentRow, token);
            if ~isempty(currentRow)
                rows{end+1} = currentRow; %#ok<AGROW>
                currentRow = {};
            end
        elseif depth == 0 && (character == ',' || isspace(character))
            [currentRow, token] = closeToken(currentRow, token);
        else
            token(end+1) = character; %#ok<AGROW>
        end
    end
    currentRow = closeToken(currentRow, token);
    if ~isempty(currentRow)
        rows{end+1} = currentRow;
    end
    isBalanced = depth == 0 && ~inQuote;
end

function [row, token] = closeToken(row, token)
    if ~isempty(token)
        row{end+1} = token;
    end
    token = '';
end
