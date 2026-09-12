function folderPath = projectdir()
%projectdir Root directory of the NANSEN-TwoPhoton repository
    folderPath = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
