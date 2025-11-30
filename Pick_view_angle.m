function Pick_view_angle
% Pick_view_angle.m
% -------------------------------------------------------------
% Rotate with the mouse to choose a nice camera angle.
% - Button "Print view [az el]" prints the azimuth/elevation.
% - Button "Play movement" plays the whole sequence with the
%   current viewing angle.

    clear; clc; close all;

    % ===== USER SETTINGS =====
    dataPath    = '/Users/idilsu/Documents/Representations/Chosen_skeletons';
    fileFilter  = '*C001*.skeleton';   % just take one front camera file
    FRAME_PAUSE = 0.03;                % speed for "Play movement"
    % =========================

    files = dir(fullfile(dataPath, fileFilter));
    if isempty(files)
        error('No skeleton files found. Check dataPath/fileFilter.');
    end

    % --- I will use ONLY the first matching file to choose a view ---
    file = fullfile(dataPath, files(1).name);
    fprintf('Using file: %s\n', files(1).name);

    S = read_skeleton_file(file);
    if isempty(S)
        error('No frames in this skeleton file.');
    end

    % ---------- find the first frame with a valid body ----------
    b = [];
    startFrame = 1;
    for t = 1:numel(S)
        if isfield(S(t),'bodies') && ~isempty(S(t).bodies)
            if isfield(S(t).bodies(1),'joints') && numel(S(t).bodies(1).joints) >= 25
                b = S(t).bodies(1);
                startFrame = t;
                break;
            end
        end
    end

    if isempty(b)
        error('No valid body with joints found in this file.');
    end

    % NTU joints (Kinect): X = left-right, Y = up-down, Z = depth
    Xk = [b.joints.x]';
    Yk = [b.joints.y]';   % UP
    Zk = [b.joints.z]';   % DEPTH

    % Plotting convention: X = left-right, Y = depth, Z = up
    X = Xk;
    Y = Zk;
    Z = Yk;

    % Center on spine base (joint 1)
    spine0 = [X(1) Y(1) Z(1)];
    J = [X Y Z] - spine0;

    % NTU 25-joint connections
    connections = [ ...
        1 2; 2 21; 21 3; 3 4; ...
        21 5; 5 6; 6 7; 7 8; 8 22; 7 23; ...
        21 9; 9 10; 10 11; 11 12; 12 24; 11 25; ...
        1 13; 13 14; 14 15; 15 16; ...
        1 17; 17 18; 18 19; 19 20];

    fig = figure('Name','Choose Skeleton View','NumberTitle','off', ...
                 'Position',[100 100 1000 800]);

    grid on; axis equal; hold on;

    % clearer labels: what each axis is
    xlabel('Left–Right (X)');
    ylabel('Depth (Z original)');
    zlabel('Up (Y original)');

    colors = lines(size(connections,1));

    % --- draw bones once and keep handles ---
    hBones = gobjects(size(connections,1),1);
    for k = 1:size(connections,1)
        p = connections(k,1); c = connections(k,2);
        hBones(k) = plot3([J(p,1) J(c,1)], [J(p,2) J(c,2)], [J(p,3) J(c,3)], '-', ...
                          'LineWidth', 4, 'Color', colors(k,:));
    end

    % --- draw joints (one handle) ---
    hJoints = plot3(J(:,1), J(:,2), J(:,3), 'o', 'MarkerSize', 4, ...
                    'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k');

    % Nice tight limits
    maxRange = max(max(abs(J))) * 1.2;
    xlim([-maxRange maxRange]);
    ylim([-maxRange maxRange]);
    zlim([-maxRange maxRange]);

    rotate3d(fig,'on');  % allow free mouse rotation

    title({'Rotate with the mouse to choose a view.'; ...
           'Then click "Print view" or "Play movement".'});

    % ---- Button: print the view angles ----
    uicontrol('Style','pushbutton', ...
              'String','Print view [az el]', ...
              'FontSize',10, ...
              'Position',[20 20 160 30], ...
              'Callback',@printViewAngles);

    % ---- Button: play full movement ----
    uicontrol('Style','pushbutton', ...
              'String','Play movement', ...
              'FontSize',10, ...
              'Position',[200 20 140 30], ...
              'Callback',@playMovement);

    % ================= NESTED FUNCTIONS =================

    function printViewAngles(~,~)
        [az,el] = view(gca);
        fprintf('\nUse this in your main code:\n');
        fprintf('AZEL = [%.1f %.1f];\n\n', az, el);
    end

    function playMovement(~,~)
        % keep current camera angle
        [az0, el0] = view(gca);

        for tt = startFrame:numel(S)
            if ~isfield(S(tt),'bodies') || isempty(S(tt).bodies), continue; end
            bb = S(tt).bodies(1);
            if ~isfield(bb,'joints') || numel(bb.joints) < 25, continue; end

            Xk = [bb.joints.x]';
            Yk = [bb.joints.y]';
            Zk = [bb.joints.z]';

            X = Xk;
            Y = Zk;
            Z = Yk;

            Jt = [X Y Z] - spine0;

            % update bones
            for kk = 1:size(connections,1)
                p = connections(kk,1); c = connections(kk,2);
                set(hBones(kk), ...
                    'XData',[Jt(p,1) Jt(c,1)], ...
                    'YData',[Jt(p,2) Jt(c,2)], ...
                    'ZData',[Jt(p,3) Jt(c,3)]);
            end

            % update joints
            set(hJoints, ...
                'XData',Jt(:,1), ...
                'YData',Jt(:,2), ...
                'ZData',Jt(:,3));

            % keep the chosen view
            view(gca, az0, el0);

            drawnow;
            pause(FRAME_PAUSE);
        end
    end

end
