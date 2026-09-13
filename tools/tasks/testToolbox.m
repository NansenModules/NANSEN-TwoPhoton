function testToolbox(varargin)
%testToolbox Run the module test suite against a NANSEN installation
%
%   Called by the matbox-actions test-code action with the source, tests
%   and report options as name-value pairs, which are forwarded to
%   matbox.tasks.testToolbox.
%
%   NANSEN is the runtime host of this module. It is installed here
%   without MatBox's genpath so that NANSEN's own tests/ and tools/
%   folders stay off the path (they hold a competing testToolbox), and
%   only its code folder is added. MatBox does not install requirements
%   transitively, so NANSEN's requirements are installed explicitly from
%   the NANSEN folder before the module's own requirements.

    projectRoot = twophotontools.projectdir();
    nansenSource = getNansenSourceUri(projectRoot);

    nansenInstall = matbox.setup.installFromSourceUri(nansenSource, ...
        "AddToPath", false, "Verbose", true);
    addpath(genpath(fullfile(nansenInstall.FilePath, "code")))

    installNansenRequirements(nansenInstall.FilePath)
    matbox.installRequirements(projectRoot, "AgreeToLicenses", true)

    matbox.tasks.testToolbox(projectRoot, varargin{:})
end

function installNansenRequirements(nansenFolder)
%installNansenRequirements Install NANSEN's requirements except this module
%
%   NANSEN requires this module, so its requirements list the module's
%   own repository. The checkout being tested already is the module, and
%   MatBox would resolve the entry to the wrong folder on a GitHub runner
%   (the repository is checked out at <name>/<name>), so that entry is
%   skipped and everything else is installed as installRequirements would.
    requirements = matbox.setup.internal.getRequirements(nansenFolder);
    isKnownType = ismember(string({requirements.Type}), ["GitHub", "FileExchange"]);
    isThisModule = contains(string({requirements.URI}), "NansenModules/NANSEN-TwoPhoton");
    for requirement = requirements(isKnownType & ~isThisModule)
        matbox.setup.installFromSourceUri(requirement.URI, ...
            "AgreeToLicense", true, "Verbose", true);
    end
end

function sourceUri = getNansenSourceUri(projectRoot)
%getNansenSourceUri Read the NANSEN line from requirements.txt
%
%   Keeps the NANSEN branch in one place (requirements.txt) so that
%   switching from the transition branch to dev is a one-line change.
    requirements = matbox.setup.internal.getRequirements(projectRoot);
    isNansen = contains([requirements.URI], "github.com/VervaekeLab/NANSEN");
    if ~any(isNansen)
        error("NANSENTwoPhoton:Tools:NansenRequirementMissing", ...
            "requirements.txt must list the NANSEN repository.")
    end
    sourceUri = requirements(find(isNansen, 1)).URI;
end
