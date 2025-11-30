function positions = extract_positions(filename)
% Returns positions: T x J x 3 numeric array

bodyinfo = read_skeleton_file(filename);

T = numel(bodyinfo);
J = bodyinfo(1).bodies(1).jointCount;

positions = zeros(T, J, 3);

for f = 1:T
    b = bodyinfo(f).bodies(1); % take main body
    for j = 1:J
        positions(f,j,1) = b.joints(j).x;
        positions(f,j,2) = b.joints(j).y;
        positions(f,j,3) = b.joints(j).z;
    end
end

end