% Get_data_points_f_objective_analysis.m


% 1. Choose the CLEAN skeleton file
filename = fullfile('Chosen_skeletons', 'S018C001P008R002A111.skeleton');  % thumb up clean

% 2. Call the function we defined in extract_positions_clean.m
positions = extract_positions(filename);

% 3. Save as .mat for Python
save('stomp.mat', 'positions');

disp('Saved positions from clean file')