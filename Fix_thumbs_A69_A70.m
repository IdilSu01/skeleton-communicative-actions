% Make_clean_thumbs.m
% -------------------------------------------------------------
% Build CLEAN synthetic sequences for:
%   A069 (thumb up)  &  A070 (thumb down)
%
% Canonical STANDING skeleton:
%   - legs slightly apart & bent (more natural)
%   - left arm relaxed
%   - RIGHT arm:
%       • starts down along body
%       • smoothly swings out and bends at the elbow
%         (hand around chest height, slightly in front/side)
%       • thumb clearly UP (A069) or DOWN (A070)
%   - Proportions tuned so: forearm > hand > thumb
%
% Output: *_clean.mat files with variable S_clean.

clear; clc;

dataPath = '/Users/idilsu/Documents/Representations/Chosen_skeletons';

% Patterns for original NTU skeletons (any camera)
patterns = { '*A069*.skeleton', ...  % thumb up
             '*A070*.skeleton' };    % thumb down

% Animation timing (frames)
nTotal = 80;   % total frames
nRest1 = 15;   % stand still at start
nRaise = 25;   % arm swing
nThumb = 15;   % thumb moving
% remaining frames = hold final pose

for p = 1:numel(patterns)

    files = dir(fullfile(dataPath, patterns{p}));
    if isempty(files)
        fprintf('No files for pattern %s, skipping.\n', patterns{p});
        continue;
    end

    for f = 1:numel(files)
        inFile = fullfile(dataPath, files(f).name);
        fprintf('\n=== Making clean sequence from %s ===\n', files(f).name);

        S_orig = read_skeleton_file(inFile);
        if isempty(S_orig)
            warning('  -> no frames in file, skipping');
            continue;
        end

        % --- take FIRST VALID FRAME as TEMPLATE (for struct only) ---
        baseFrameIdx = [];
        for t = 1:numel(S_orig)
            if isfield(S_orig(t),'bodies') && ~isempty(S_orig(t).bodies)
                b = S_orig(t).bodies(1);
                if isfield(b,'joints') && numel(b.joints) >= 25
                    baseFrameIdx = t;
                    break;
                end
            end
        end

        if isempty(baseFrameIdx)
            warning('  -> no valid body in file, skipping');
            continue;
        end

        baseFrame = S_orig(baseFrameIdx);

        % =============================================================
        %            CANONICAL STANDING POSE  J0  (NTU coords)
        % =============================================================
        % NTU: x = left-right, y = up-down, z = depth

        J0 = zeros(25,3);

        % --- spine & head (1,2,21,3,4) ---
        J0(1,:)  = [0,  0.00,  0.0];   % spine base (pelvis)
        J0(2,:)  = [0,  0.20,  0.0];   % spine mid
        J0(21,:) = [0,  0.40,  0.0];   % neck
        J0(3,:)  = [0,  0.55,  0.0];   % head
        J0(4,:)  = [0,  0.65,  0.0];   % head top

        % --- LEFT arm (5,6,7,8): relaxed, slightly down and forward ---
        J0(5,:) = [-0.15, 0.40,  0.0];  % left shoulder
        J0(6,:) = [-0.25, 0.30,  0.02]; % left elbow
        J0(7,:) = [-0.30, 0.18,  0.04]; % left wrist
        J0(8,:) = [-0.32, 0.08,  0.05]; % left hand

        % --- RIGHT arm base pose (down along body, slightly forward) ---
        J0(9,:)  = [ 0.15, 0.40,  0.0]; % right shoulder
        J0(10,:) = [ 0.15, 0.25,  0.01];% elbow directly below shoulder
        J0(11,:) = [ 0.15, 0.10,  0.02];% wrist below elbow
        J0(12,:) = [ 0.15,-0.05,  0.03];% hand along body

        % --- LEFT leg (13,14,15,16): slight bend, feet apart ---
        J0(13,:) = [-0.10,  0.00,  0.0];  % left hip
        J0(14,:) = [-0.11, -0.30, 0.02];  % left knee a bit forward
        J0(15,:) = [-0.12, -0.60, 0.04];  % left ankle
        J0(16,:) = [-0.14, -0.85, 0.06];  % left foot slightly forward/out

        % --- RIGHT leg (17,18,19,20): same idea ---
        J0(17,:) = [ 0.10,  0.00,  0.0];  % right hip
        J0(18,:) = [ 0.11, -0.30, 0.02];  % right knee
        J0(19,:) = [ 0.12, -0.60, 0.04];  % right ankle
        J0(20,:) = [ 0.14, -0.85, 0.06];  % right foot

        % =============================================================
        %   Right hand tip + thumb (proportions tuned) in base pose
        % =============================================================
        handR = 12;
        ha0   = J0(handR,:);  % base hand position

        % Offsets *relative to the hand*:
        %   - tip a bit further out
        %   - thumb shorter, closer to hand
        neutralTipOffset   = [0.05, 0.020, 0.00];   % ~5 cm out, 2 cm up
        neutralThumbOffset = [0.03, 0.015, 0.00];   % ~3 cm out, 1.5 cm up

        J0(24,:) = ha0 + neutralTipOffset;   % right hand tip
        J0(25,:) = ha0 + neutralThumbOffset; % right thumb

        % left tip/thumb (static, we don't care)
        J0(22,:) = J0(8,:) + [-0.05, 0.020, 0.00];
        J0(23,:) = J0(8,:) + [-0.03, 0.015, 0.00];

        % =============================================================
        %      DEFINE BASE & TARGET FOR RIGHT ARM + RIGHT THUMB
        % =============================================================

        shoulderR = 9;
        elbowR    = 10;
        wristR    = 11;
        thumbR    = 25;
        tipR      = 24;

        % base arm pose (down)
        el0 = J0(elbowR,:);
        wr0 = J0(wristR,:);
        % ha0 already defined above from handR

        % ---------- Target arm pose: bent to the side/front ----------
        % Shoulder stays at same place. We put elbow & hand so that:
        %   - elbow slightly out + slightly up
        %   - hand around chest height, a bit in front
        sh0 = J0(shoulderR,:);

        elSide = [sh0(1) + 0.18, sh0(2) + 0.02,  0.04];  % elbow out + a bit up
        wrSide = [sh0(1) + 0.28, sh0(2) - 0.01,  0.10];  % wrist further from elbow
        haSide = [sh0(1) + 0.40, sh0(2) - 0.05,  0.14];  % hand clearly beyond wrist

        % decide thumb direction from filename
        if contains(files(f).name, 'A069')
            thumbMode = 'up';
        else
            thumbMode = 'down';
        end

        % thumb shift: up/down relative to the hand (visible but not huge)
        thumbShiftY = 0.04;   % 4 cm up/down

        if strcmp(thumbMode,'up')
            thumbTargetOffset = neutralThumbOffset + [0, +thumbShiftY, 0];
        else
            thumbTargetOffset = neutralThumbOffset + [0, -thumbShiftY, 0];
        end

        % =============================================================
        %                BUILD NEW CLEAN SEQUENCE
        % =============================================================

        S_clean = repmat(baseFrame, 1, nTotal);  % copy template frame

        for t = 1:nTotal
            % start from the global standing pose
            Jt = J0;

            if t <= nRest1
                % phase 1: fully static, arm down
                % Jt = J0

            elseif t <= nRest1 + nRaise
                % phase 2: arm swing with smooth easing
                s = (t - nRest1) / nRaise;         % 0 -> 1
                s = max(0,min(1,s));
                alpha = 0.5 - 0.5*cos(pi*s);      % cosine ease-in-out

                Jt(elbowR,:) = (1-alpha)*el0 + alpha*elSide;
                Jt(wristR,:) = (1-alpha)*wr0 + alpha*wrSide;
                Jt(handR,:)  = (1-alpha)*ha0 + alpha*haSide;

                % tip follows hand with neutral offset
                Jt(tipR,:)   = Jt(handR,:) + neutralTipOffset;
                % thumb follows hand in neutral pose
                Jt(thumbR,:) = Jt(handR,:) + neutralThumbOffset;

            elseif t <= nRest1 + nRaise + nThumb
                % phase 3: thumb moving, arm fixed in final pose
                s2 = (t - (nRest1 + nRaise)) / nThumb;  % 0 -> 1
                s2 = max(0,min(1,s2));
                beta = 0.5 - 0.5*cos(pi*s2);           % smooth easing

                Jt(elbowR,:) = elSide;
                Jt(wristR,:) = wrSide;
                Jt(handR,:)  = haSide;

                % tip stays with neutral offset
                Jt(tipR,:) = Jt(handR,:) + neutralTipOffset;

                % thumb interpolates from neutral to target offset
                currOffset = (1-beta)*neutralThumbOffset + beta*thumbTargetOffset;
                Jt(thumbR,:) = Jt(handR,:) + currOffset;

            else
                % phase 4: hold final pose
                Jt(elbowR,:) = elSide;
                Jt(wristR,:) = wrSide;
                Jt(handR,:)  = haSide;
                Jt(tipR,:)   = Jt(handR,:) + neutralTipOffset;
                Jt(thumbR,:) = Jt(handR,:) + thumbTargetOffset;
            end

            % write Jt into S_clean(t)
            for j = 1:25
                S_clean(t).bodies(1).joints(j).x = Jt(j,1);
                S_clean(t).bodies(1).joints(j).y = Jt(j,2);
                S_clean(t).bodies(1).joints(j).z = Jt(j,3);
            end
        end

        % ---------- save result ----------
        [~, baseName, ~] = fileparts(files(f).name);
        outFile = fullfile(dataPath, [baseName '_clean.mat']);
        save(outFile, 'S_clean');

        fprintf('  -> saved %s\n', [baseName '_clean.mat']);
    end
end

fprintf('\nAll clean sequences done.\n');