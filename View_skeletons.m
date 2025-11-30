function View_skeletons
% View_skeletons.m
% -------------------------------------------------------------
% Plays all skeleton files in a folder:
%   - Original  *.skeleton  files (via read_skeleton_file)
%   - Modified *_clean.mat  (S_clean)
%   - Modified *_fixed.mat  (S_fix)
%
% Uses AZEL (view angle) from Pick_view_angle.m.
%
% Controls (during animation, at ANY time):
%   →  Right arrow : go immediately to next file
%   ←  Left arrow  : go immediately to previous file
%   ESC            : quit viewer

    clear; clc; close all;

    % ===== USER SETTINGS =====
    dataPath    = '/Users/idilsu/Documents/Representations/Chosen_skeletons';

    % Only C001 camera versions:
    fileFilterSkeleton = '*C001*.skeleton';
    fileFilterMatClean = '*C001*_clean.mat';
    fileFilterMatFix   = '*C001*_fixed.mat';

    LINEWIDTH   = 5;        % thickness of bones
    MARKERSIZE  = 1.8;      % joint marker size
    FRAME_PAUSE = 0.05;     % playback speed (seconds)

    % >>> paste your favorite view from Pick_view_angle here <<<
    AZEL        = [35 12];  % [azimuth elevation] example
    % ==========================

    % navigation command updated by keyPress callback
    navCmd = '';  % '' = nothing, 'next', 'prev', 'quit'

    % ---- Collect files ----
    filesSkel     = dir(fullfile(dataPath, fileFilterSkeleton));
    filesMatClean = dir(fullfile(dataPath, fileFilterMatClean));
    filesMatFix   = dir(fullfile(dataPath, fileFilterMatFix));

    files = [filesSkel; filesMatClean; filesMatFix];

    if isempty(files)
        fprintf('No skeleton / *_clean.mat / *_fixed.mat files found.\n');
        return;
    end

    % sort by name
    [~, idxSort] = sort({files.name});
    files = files(idxSort);

    fprintf('Found %d files:\n', numel(files));
    for i = 1:numel(files)
        fprintf('  %2d: %s\n', i, files(i).name);
    end

    % ---- Base body connections (no fingers) ----
    baseConnections = [ ...
        1 2; 2 21; 21 3; 3 4; ...
        21 5; 5 6; 6 7; 7 8; ...          % left arm to hand (8)
        21 9; 9 10; 10 11; 11 12; ...     % right arm to hand (12)
        1 13; 13 14; 14 15; 15 16; ...    % left leg
        1 17; 17 18; 18 19; 19 20];       % right leg

    nBaseConn = size(baseConnections,1);
    colorsBase = lines(nBaseConn);

    % For thumb actions, we add ONE extra bone: right hand (12) -> right thumb (25)
    thumbConnection = [12 25];

    % Create figure
    fig = figure('Name','NTU Skeleton Viewer','NumberTitle','off', ...
                 'Position',[100 100 1400 1000]);
    set(fig,'KeyPressFcn',@keyPressed);   % ESC / arrows handler

    nFiles  = numel(files);
    fileIdx = 1;                          % start on first file

    while fileIdx >= 1 && fileIdx <= nFiles

        % reset navigation command at the start of each file
        navCmd = '';

        fileName = files(fileIdx).name;
        filePath = fullfile(dataPath, fileName);
        [~, ~, ext] = fileparts(fileName);

        fprintf('\n=== Now showing (%d/%d): %s ===\n', ...
            fileIdx, nFiles, fileName);

        % Is this a special thumb action?
        isThumbAction = contains(fileName, 'A069') || contains(fileName, 'A070');

        % ----- Load skeleton depending on extension -----
        if strcmpi(ext, '.skeleton')
            S = read_skeleton_file(filePath);
        elseif strcmpi(ext, '.mat')
            tmp = load(filePath);
            if isfield(tmp, 'S_clean')
                S = tmp.S_clean;
            elseif isfield(tmp, 'S_fix')
                S = tmp.S_fix;
            elseif isfield(tmp, 'S')
                S = tmp.S;
            else
                warning('No S_clean, S_fix or S in %s, skipping.', fileName);
                fileIdx = fileIdx + 1;
                continue;
            end
        else
            warning('Unknown file type: %s, skipping.', fileName);
            fileIdx = fileIdx + 1;
            continue;
        end

        if isempty(S)
            warning('No frames in %s', fileName);
            fileIdx = fileIdx + 1;
            continue;
        end

        nF = numel(S);

        % ---------- PASS 1: compute extents + reference spine ----------
        firstSpine = [];
        allX = []; allY = []; allZ = [];

        for t = 1:nF
            if ~isfield(S(t),'bodies') || isempty(S(t).bodies), continue; end
            b = S(t).bodies(1);
            if ~isfield(b,'joints') || numel(b.joints) < 25, continue; end

            % NTU coordinates: X=left-right, Y=up, Z=depth
            Xk = [b.joints.x]';
            Yk = [b.joints.y]';
            Zk = [b.joints.z]';

            % Plot convention: X = left-right, Y = depth, Z = up
            X = Xk;
            Y = Zk;
            Z = Yk;

            if isempty(firstSpine)
                firstSpine = [X(1) Y(1) Z(1)];
            end

            J = [X Y Z] - firstSpine;

            allX = [allX; J(:,1)];
            allY = [allY; J(:,2)];
            allZ = [allZ; J(:,3)];
        end

        if isempty(allX)
            warning('No valid joints in %s', fileName);
            fileIdx = fileIdx + 1;
            continue;
        end

        margin   = 1.1;
        maxRange = max([max(abs(allX)), max(abs(allY)), max(abs(allZ))]) * margin;
        if maxRange <= 0 || isnan(maxRange)
            maxRange = 1;
        end

        % ---------- prepare axes for this file ----------
        clf(fig);
        grid on; axis equal; hold on;
        xlabel('X');
        ylabel('Z');
        zlabel('Y');
        title(fileName, 'Interpreter','none','FontSize',12,'FontWeight','bold');
        xlim([-maxRange maxRange]);
        ylim([-maxRange maxRange]);
        zlim([-maxRange maxRange]);
        view(AZEL(1), AZEL(2));

        % ---------- PASS 2: animate with live navigation ----------
        for t = 1:nF
            % check if user requested navigation
            if ~isempty(navCmd)
                break;
            end

            if ~isfield(S(t),'bodies') || isempty(S(t).bodies), continue; end
            b = S(t).bodies(1);
            if ~isfield(b,'joints') || numel(b.joints) < 25, continue; end

            Xk = [b.joints.x]';
            Yk = [b.joints.y]';
            Zk = [b.joints.z]';

            X = Xk;
            Y = Zk;
            Z = Yk;

            if isempty(firstSpine)
                firstSpine = [X(1) Y(1) Z(1)];
            end
            J = [X Y Z] - firstSpine;

            cla; hold on; grid on; axis equal;
            xlim([-maxRange maxRange]);
            ylim([-maxRange maxRange]);
            zlim([-maxRange maxRange]);
            view(AZEL(1), AZEL(2));

            title(sprintf('%s — Frame %d/%d', fileName, t, nF), ...
                  'Interpreter','none');

            % ----- BODY BONES (always) -----
            for k = 1:nBaseConn
                p = baseConnections(k,1);
                c = baseConnections(k,2);
                plot3([J(p,1) J(c,1)], ...
                      [J(p,2) J(c,2)], ...
                      [J(p,3) J(c,3)], '-', ...
                      'LineWidth', LINEWIDTH, 'Color', colorsBase(k,:));
            end

            % ----- THUMB BONE (only for A069 / A070) -----
            if isThumbAction
                p = thumbConnection(1);
                c = thumbConnection(2);
                plot3([J(p,1) J(c,1)], ...
                      [J(p,2) J(c,2)], ...
                      [J(p,3) J(c,3)], '-', ...
                      'LineWidth', LINEWIDTH, 'Color', [0.2 0.2 0.2]);
            end

            % ----- JOINT DOTS -----
            if isThumbAction
                % Show all joints except the useless tips (22,24),
                % keep thumb (25) and left thumb (23) if present.
                hideIdx = [22 24];
                showIdx = setdiff(1:25, hideIdx);
            else
                % For all other actions: hide tips + thumbs
                hideIdx = [22 23 24 25];
                showIdx = setdiff(1:25, hideIdx);
            end

            % normal joints
            plot3(J(showIdx,1), J(showIdx,2), J(showIdx,3), 'o', ...
                  'MarkerSize', MARKERSIZE, ...
                  'MarkerFaceColor','r', ...
                  'MarkerEdgeColor','k');

            % Make right thumb extra visible in 69/70
            if isThumbAction
                thumbID = 25;
                plot3(J(thumbID,1), J(thumbID,2), J(thumbID,3), 'o', ...
                      'MarkerSize', MARKERSIZE*3, ...
                      'MarkerFaceColor','g', ...
                      'MarkerEdgeColor','k');
            end

            drawnow;
            pause(FRAME_PAUSE);
        end

        % ---------- Act on navigation command ----------
        if strcmp(navCmd, 'quit')
            break;
        elseif strcmp(navCmd, 'next')
            if fileIdx < nFiles
                fileIdx = fileIdx + 1;
            else
                disp('Already at last file.');
            end
            continue;
        elseif strcmp(navCmd, 'prev')
            if fileIdx > 1
                fileIdx = fileIdx - 1;
            else
                disp('Already at first file.');
            end
            continue;
        else
            % no navigation pressed during animation → auto-next
            if fileIdx < nFiles
                fileIdx = fileIdx + 1;
            else
                break;
            end
        end
    end

    close all;
    fprintf('\nStopped.\n');

    % -------- Key press handler (nested) --------
    function keyPressed(~, event)
        switch event.Key
            case 'escape'
                navCmd = 'quit';
                disp('ESC pressed — quitting viewer...');
            case 'rightarrow'
                navCmd = 'next';
            case 'leftarrow'
                navCmd = 'prev';
        end
    end
end