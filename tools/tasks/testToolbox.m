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

    matbox.installRequirements(nansenInstall.FilePath, "AgreeToLicenses", true)
    matbox.installRequirements(projectRoot, "AgreeToLicenses", true)

    matbox.tasks.testToolbox(projectRoot, varargin{:})
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
