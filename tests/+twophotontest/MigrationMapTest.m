classdef MigrationMapTest < matlab.unittest.TestCase
%MigrationMapTest The shipped identifier rename map is well-formed and applies
%
%   Checks resources/migration/identifier_renames.json, which
%   nansen.module.twophoton.migrateProject feeds to NANSEN's
%   renameStoredIdentifiers, and runs the migration on a minimal project
%   folder that still stores the pre-migration module name.
%
%   Run tests:
%       runtests('twophotontest.MigrationMapTest')

    properties (Constant, Access = private)
        OldModuleName = "nansen.module.ophys.twophoton"
    end

    methods (Access = private)
        function renames = loadRenameMap(testCase)
            moduleEntry = twophotontest.helper.findModuleEntry();
            mapPath = fullfile(moduleEntry.FolderPath, 'resources', 'migration', 'identifier_renames.json');
            testCase.assertTrue(isfile(mapPath), 'The rename map resource is missing')
            renames = jsondecode(fileread(mapPath)).Renames;
            % Entries with identical fields decode to a struct array; keep
            % the test robust if a future entry gains an extra field.
            if iscell(renames)
                renames = cellfun(@(c) struct('Old', string(c.Old), 'New', string(c.New), ...
                    'Match', string(c.Match)), renames);
            end
        end

        function projectFolder = createOldProjectFolder(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            projectFolder = char(testCase.applyFixture(TemporaryFolderFixture).Folder);
            specification = struct('Properties', struct('Name', 'OldProject'), ...
                'Preferences', struct('DataModule', {{char(testCase.OldModuleName), 'nansen.module.general.core'}}));
            fileId = fopen(fullfile(projectFolder, 'project.nansen.json'), 'w');
            testCase.assertNotEqual(fileId, -1)
            fwrite(fileId, jsonencode(specification, 'PrettyPrint', true), 'char');
            fclose(fileId);
        end
    end

    methods (Test)

        function testEveryEntryTargetsTheModule(testCase)
            renames = testCase.loadRenameMap();
            testCase.verifyNotEmpty(renames)
            newNames = string({renames.New});
            testCase.verifyTrue(all(startsWith(newNames, twophotontest.helper.modulePackageName())))
            matchKinds = string({renames.Match});
            testCase.verifyTrue(all(ismember(matchKinds, ["exact", "prefix"])))
        end

        function testModuleRenameIsCovered(testCase)
            renames = testCase.loadRenameMap();
            isModuleRename = string({renames.Old}) == testCase.OldModuleName & string({renames.Match}) == "exact";
            testCase.verifyEqual(nnz(isModuleRename), 1)
            testCase.verifyEqual(string(renames(isModuleRename).New), twophotontest.helper.modulePackageName())
        end

        function testDryRunReportsTheModuleSelection(testCase)
            projectFolder = testCase.createOldProjectFolder();
            report = nansen.module.twophoton.migrateProject(projectFolder, 'Verbose', false);
            testCase.verifyTrue(any(report.Old == testCase.OldModuleName & report.New == twophotontest.helper.modulePackageName()))
            specification = jsondecode(fileread(fullfile(projectFolder, 'project.nansen.json')));
            testCase.verifyEqual(string(specification.Preferences.DataModule{1}), testCase.OldModuleName)
        end

        function testApplyRewritesTheModuleSelection(testCase)
            projectFolder = testCase.createOldProjectFolder();
            nansen.module.twophoton.migrateProject(projectFolder, 'DryRun', false, 'Backup', false, 'Verbose', false);
            specification = jsondecode(fileread(fullfile(projectFolder, 'project.nansen.json')));
            testCase.verifyEqual(string(specification.Preferences.DataModule{1}), twophotontest.helper.modulePackageName())
            testCase.verifyEqual(specification.Preferences.DataModule{2}, 'nansen.module.general.core')
        end
    end
end
