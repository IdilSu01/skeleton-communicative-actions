function positions = extract_positions_clean(matfile)
% EXTRACT_POSITIONS_CLEAN  Return positions [T x J x 3] from *_clean.mat
%
%   matfile: path to a .mat file containing S_clean
%   positions: numeric array [T x J x 3] (frames x joints x xyz)

data = load(matfile);   % loads S_clean

if ~isfield(data, 'S_clean')
    error('File %s does not contain S_clean.', matfile);
end

bodyinfo = data.S_clean;    % same kind of struct as original bodyinfo

T = numel(bodyinfo);
if T == 0
    error('S_clean is empty in %s.', matfile);
end

% assume one body with 25 joints
b1 = bodyinfo(1).bodies(1);
J  = numel(b1.joints);  % or b1.jointCount if you prefer

positions = zeros(T, J, 3);

for t = 1:T
    b = bodyinfo(t).bodies(1);   % take main body
    for j = 1:J
        positions(t,j,1) = b.joints(j).x;
        positions(t,j,2) = b.joints(j).y;
        positions(t,j,3) = b.joints(j).z;
    end
end

end