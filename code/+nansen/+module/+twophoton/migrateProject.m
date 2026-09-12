function report = migrateProject(project, options)
%migrateProject Rewrite a project's stored two-photon identifiers after the module move
%
%   report = nansen.module.twophoton.migrateProject(project) previews the
%   stored identifiers that changed when the two-photon module moved out
%   of NANSEN core into its own repository: the module name in the
%   project's module selection, session-method and processor names in
%   pipelines and catalogs, and the option-set files that are keyed by
%   processor name. Nothing is modified.
%
%   report = nansen.module.twophoton.migrateProject(project, DryRun=false)
%   applies the changes in place and keeps a backup of every changed file
%   next to it (Backup=false disables the backups).
%
%   project is the path of a project folder, or the name of a project in
%   the current user's project catalog. The user-level custom options
%   folder is scanned too, because option sets of module functions are
%   stored there.
%
%   The rename map is resources/migration/identifier_renames.json in this
%   package.
%
%   See also nansen.config.project.renameStoredIdentifiers

    arguments
        project (1,1) string
        options.DryRun (1,1) logical = true
        options.Backup (1,1) logical = true
        options.Verbose (1,1) logical = true
    end

    projectFolder = resolveProjectFolder(project);
    renameMapPath = fullfile(fileparts(mfilename('fullpath')), ...
        'resources', 'migration', 'identifier_renames.json');

    extraFolders = string.empty(1, 0);
    localOptionsFolder = getLocalOptionsFolder();
    if isfolder(localOptionsFolder)
        extraFolders(end+1) = localOptionsFolder;
    end

    report = nansen.config.project.renameStoredIdentifiers(projectFolder, renameMapPath, ...
        "DryRun", options.DryRun, "Backup", options.Backup, ...
        "ExtraFolders", extraFolders, "Verbose", options.Verbose);
end

function projectFolder = resolveProjectFolder(project)
%resolveProjectFolder Accept a folder path or a project name from the catalog
    if isfolder(project)
        projectFolder = project;
        return
    end

    projectManager = nansen.config.project.ProjectManager.instance();
    if ~projectManager.containsProject(project)
        error('NANSEN:TwoPhoton:ProjectNotFound', ...
            ['"%s" is neither an existing folder nor the name of a project ', ...
             'in the current project catalog.'], project)
    end
    projectFolder = string(projectManager.getProjectObject(project).FolderPath);
end

function folderPath = getLocalOptionsFolder()
%getLocalOptionsFolder The user-level custom options folder, or "" if unavailable
    try
        folderPath = string(nansen.localpath('custom_options'));
    catch
        % Without a user session there is no local options folder to scan;
        % the project folder alone is migrated.
        folderPath = "";
    end
end
