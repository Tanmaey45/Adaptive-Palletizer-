function place3DBoxesFromExcel()
    % Read Excel file
    filename = 'Boxes.xlsx';
    sheetName = 'Sheet2';  % or you can use the sheet index, e.g., 1

    data = readtable(filename, 'Sheet', sheetName);

    % Assume columns: Length, Breadth, Weight
    input_rectangles = [data{:,2}, data{:,3}, data{:,4}];
    N = size(input_rectangles, 1);

    % Add initial 0.2 x 0.2 rectangle with arbitrary weight (e.g. 5)
    rectangles = [[0.2, 0.2, 5]; input_rectangles];

    % Add ID and Planar Density column
    IDs = (1:size(rectangles,1))';
    planar_density = rectangles(:,3) ./ (rectangles(:,1) .* rectangles(:,2));
    rectangles = [rectangles, planar_density, IDs];

    % Sort by descending planar density
    rectangles_sorted = sortrows(rectangles, -4); % 4th column is planar density

    % Split into bottom and top layers
    N_total = size(rectangles_sorted,1);  
    N_bottom = round(0.6 * N_total);
    bottom_rects = rectangles_sorted(1:N_bottom, :);
    top_rects = rectangles_sorted(N_bottom+1:end, :);

    % Place bottom layer
    TOP_LEFT_pallete = [0, -0.42];
    BOTTOM_RIGHT_pallete = [1.1, -0.76];
    [bottom_placements, base_map, bottom_rejected_ids] = placeLayer(bottom_rects, 0, TOP_LEFT_pallete, BOTTOM_RIGHT_pallete);

    % Place top layer
    [top_placements, top_rejected_ids] = placeTopLayer(top_rects, base_map);

    % Merge placements and rejected
    all_placements = [bottom_placements; top_placements];


    % Create full result with one row per input ID (including dummy box)
    total_boxes = size(rectangles, 1);
    result = zeros(total_boxes, 9); % [X, Y, Z, L, B, W, Layer, Rejected, Rotation]
    placed_IDs = all_placements(:,8);  % Original ID

    % Fill result with placed boxes (set selected = 0)
    for i = 1:size(all_placements,1)
        id = placed_IDs(i);
        result(id,1:7) = all_placements(i,1:7); % X,Y,Z,L,B,W,Layer
        result(id,8) = 0;  % selected = 0
        result(id,9) = all_placements(i,9); % Rotation
    end

    % Mark unplaced boxes (Rejected = 1)
    all_rejected = [bottom_rejected_ids; top_rejected_ids];
    for i = 1:total_boxes
        if ismember(i, all_rejected)
            L = rectangles(i,1);
            B = rectangles(i,2);
            W = rectangles(i,3);

            %For rejected boxes, throw them at (0.3,0.8,0.3)
            result(i,:) = [0.9, 0.3, 0.55, L, B, W, 0, 1, 0]; % Rejected = 1, Rotation = 0

        end
    end

    %% ROUND 1: Assign temporary platform locations for Layer 2

    % Extract only Layer 2 boxes
    layer2_idxs = find(result(:,7) == 2 & result(:,8) == 0); % not rejected
    layer2_boxes = result(layer2_idxs, :);
% Use placeLayer logic on virtual platform
platform_top_left = [0.6, 0.5];
platform_bottom_right = [1.3, 0];
platform_margin = 0.01;
platform_spacing = 0.01;

plat_width = platform_bottom_right(1) - platform_top_left(1) - 2*platform_margin;
plat_height = platform_top_left(2) - platform_bottom_right(2) - 2*platform_margin;

plat_x = platform_top_left(1) + platform_margin;
plat_y = platform_top_left(2) - platform_margin;
shelf_h = 0;
x_cursor = plat_x;

platform_placements = zeros(size(layer2_boxes,1), 3); % store goal_x, goal_y, goal_z
z_stacks = zeros(size(layer2_boxes,1), 1);             % track stacking height (number of times placed on top)

for i = 1:size(layer2_boxes,1)
    L = layer2_boxes(i,4);
    B = layer2_boxes(i,5);
    rot = layer2_boxes(i,9);
    ID = layer2_idxs(i);

    % Determine width and height based on rotation
    w = L; h = B;
    if rot == 1
        w = B; h = L;
    end

    % If no room left in row, move to new shelf
    if (x_cursor + w + platform_spacing) > (platform_bottom_right(1) - platform_margin)
        plat_y = plat_y - (shelf_h + platform_spacing);
        x_cursor = plat_x;
        shelf_h = 0;
    end

if (plat_y - h) < (platform_bottom_right(2) + platform_margin)
    % If no space left on platform (2D), stack this box over previously placed ones with largest Z
    [~, stack_idx] = min(platform_placements(:,3)); % find lowest Z to stack on

    if platform_placements(stack_idx,3) == 0
        % No valid base yet, stack at first position
        platform_placements(i,:) = [platform_top_left(1) + 0.02*i, platform_top_left(2) - 0.02*i, 0.3];
    else
        base_pos = platform_placements(stack_idx,:);
        new_z = base_pos(3) + 0.2;
        platform_placements(i,:) = [base_pos(1), base_pos(2), new_z];
    end
    continue;
end


    % Normal placement
    platform_placements(i,:) = [x_cursor, plat_y - h, 0.3];
    x_cursor = x_cursor + w + platform_spacing;
    shelf_h = max(shelf_h, h);
end



    %% Round 1 — Create pickup-goal rows
    pickup_goal_rows = [];

    for i = 1:size(result, 1)
        L = result(i,4); B = result(i,5); W = result(i,6);
        rot = result(i,9);
        layer = result(i,7);
        rej = result(i,8);
        ID = i;

        if rej == 1
            pickup = [-0.45	-0.65 0.6];
            goal = [-0.5, -1, 1];
            pickup_goal_rows = [pickup_goal_rows;
                ID, pickup, goal, L, B, W, layer, rot, 1, rej];
        elseif layer == 1
            pickup =  [-0.45 -0.65 0.6];
            goal = result(i,1:3);
            pickup_goal_rows = [pickup_goal_rows;
                ID, pickup, goal, L, B, W, layer, rot, 1, rej];
        elseif layer == 2
            pickup =  [-0.45 -0.65 0.6];
            goal = platform_placements(layer2_idxs == i,:);
            pickup_goal_rows = [pickup_goal_rows;
                ID, pickup, goal, L, B, W, 0, rot, 1, rej]; %Layer for round is 0 for not using intermideate waypoint
        end
    end


    %% Round 2 — Pick Layer 2 boxes from platform and place to final goal (reverse order)
    for i = numel(layer2_idxs):-1:1
        idx = layer2_idxs(i);
        pickup = platform_placements(i,:);
        goal = result(idx, 1:3);
        L = result(idx, 4); B = result(idx, 5); W = result(idx, 6);
        rot = result(idx, 9);
        layer = 2;
        pickup_goal_rows = [pickup_goal_rows;
            idx, pickup, goal, L, B, W, layer, rot, 2,0];
    end
    
    % Save original Pickup and Goal coordinates
    orig_pickup_x = pickup_goal_rows(:,2);
    orig_pickup_y = pickup_goal_rows(:,3);

    orig_goal_x = pickup_goal_rows(:,5);
    orig_goal_y = pickup_goal_rows(:,6);

    % Apply: new_X = -original_Y, new_Y = original_X
    pickup_goal_rows(:,2) = orig_pickup_y;  % Pickup_X
    pickup_goal_rows(:,3) = -orig_pickup_x;   % Pickup_Y

    pickup_goal_rows(:,5) = orig_goal_y;    % Goal_X
    pickup_goal_rows(:,6) = -orig_goal_x;     % Goal_Y

    
    pickup_goal_table = array2table(pickup_goal_rows, ...
        'VariableNames', {'ID','Pickup_X','Pickup_Y','Pickup_Z', ...
        'Goal_X','Goal_Y','Goal_Z', ...
        'Length','Breadth','Weight','Layer','Rotation','Round','Rejected'});

    pickup_goal_table.Height = 0.2 * ones(height(pickup_goal_table), 1); %Add Height column, taking 0.2 for all

    writetable(pickup_goal_table, 'box_pick_goal_schedule_14.xlsx','Sheet', 'Sheet1');
    disp('box_pick_goal_schedule.xlsx with pickup-goal mappings and rejection flags saved.');

        %% Sheet2 Modifications
   % Copy original
pickup_goal_rows_modified = pickup_goal_rows;

% Step 1: Find the last row with Layer = 0 or 1
layer_col = pickup_goal_rows(:,11);  % Layer is in column 11
last_idx = find(layer_col == 0 | layer_col == 1, 1, 'last');

% Step 2: For columns ID (1), Pickup_X (2), Pickup_Y (3), Pickup_Z (4)
cols_to_modify = 1:4;

% Shift the values in those columns up by one from last_idx
for col = cols_to_modify
    pickup_goal_rows_modified(last_idx:end-1, col) = pickup_goal_rows_modified(last_idx+1:end, col);
    pickup_goal_rows_modified(end, col) = 0;  % Set the final row to 0
end

% Step 3: Decrease ID values (column 1) after last_idx by 1
for i = last_idx:size(pickup_goal_rows_modified,1)
    if pickup_goal_rows_modified(i,1) > 0  % Only if ID is > 0
        pickup_goal_rows_modified(i,1) = pickup_goal_rows_modified(i,1) - 1;
    end
end

% Step 4: Create table and write to Sheet2
pickup_goal_table2 = array2table(pickup_goal_rows_modified, ...
    'VariableNames', {'ID','Pickup_X','Pickup_Y','Pickup_Z', ...
    'Goal_X','Goal_Y','Goal_Z', ...
    'Length','Breadth','Weight','Layer','Rotation','Round','Rejected'});

pickup_goal_table2.Height = 0.2 * ones(height(pickup_goal_table2), 1);


%writetable(pickup_goal_table1, 'box_pick_goal_schedule_14.xlsx', 'Sheet', 'Sheet1');
writetable(pickup_goal_table2, 'box_pick_goal_schedule_14.xlsx', 'Sheet', 'Sheet2');

disp("✅ Sheet2 created with selective column modifications as requested.");


    % Swap X and Y, and negate the new X (which was originally Y)
    transformed_result = result;
    transformed_result(:,1) = result(:,2) ;  % new X = -original Y
    transformed_result(:,2) = -result(:,1) ;   % new Y = original X

% Save to Excel
    output = array2table(transformed_result, 'VariableNames', ...
        {'X','Y','Z','Length','Breadth','Weight','Layer','Rejected', 'Rotation'});
    writetable(output, 'box_placements_3D_10.xlsx');
    disp('Placements saved to box_placements_3D_10.xlsx');


end

function [placements, base_map, rejected_ids] = placeLayer(rectangles, z_layer, TOP_LEFT, BOTTOM_RIGHT)
    MARGIN = 0.01;
    SPACING = 0.02;

    usable_width = abs(TOP_LEFT(1) - BOTTOM_RIGHT(1)) - 2 * MARGIN;
    usable_height = abs(TOP_LEFT(2) - BOTTOM_RIGHT(2)) - 2 * MARGIN;

    shelf_y = TOP_LEFT(2) - MARGIN;
    shelf_height = 0;
    x_cursor = TOP_LEFT(1) + MARGIN;

    placements = [];
    base_map = [];
    rejected_ids = [];
    idx = 1;

    for i = 1:size(rectangles,1)
        L = rectangles(i,1);
        B = rectangles(i,2);
        W = rectangles(i,3);
        ID = rectangles(i,5);

        options = [B, L, 0; L, B, 1]; % width, depth, rotated
        options = sortrows(options, 2); % prioritize lower height

        placed = false;
        for j = 1:2
            w = options(j,1);
            h = options(j,2);
            rot = options(j,3);

            if w > usable_width || h > usable_height
                continue;
            end

            if (x_cursor + w + SPACING) > (BOTTOM_RIGHT(1) - MARGIN)
                shelf_y = shelf_y - (shelf_height + SPACING);
                x_cursor = TOP_LEFT(1) + MARGIN;
                shelf_height = 0;
            end

            if (shelf_y - h) < (BOTTOM_RIGHT(2) + MARGIN)
                continue;
            end

            placements(idx,:) = [x_cursor, shelf_y - h, z_layer, w, h, W, 1, ID, rot]; % 1 = bottom layer
            base_map(idx,:) = [x_cursor, x_cursor + w, shelf_y - h, shelf_y, W];
            x_cursor = x_cursor + w + SPACING;
            shelf_height = max(shelf_height, h);
            placed = true;
            idx = idx + 1;
            break;
        end

        if ~placed
            fprintf('Bottom layer: Box too big to fit: %f x %f\n', L, B);
            rejected_ids = [rejected_ids; ID];
        end
    end
end


function [top_placements, rejected_ids] = placeTopLayer(top_rects, base_map)
    H = 0.22;
    top_placements = [];
    rejected_ids = [];
    idx = 1;

    TOP_LEFT = [0, -0.1];
    BOTTOM_RIGHT = [1.1, -0.76];
    MARGIN = 0.01;

    x_min = TOP_LEFT(1) + MARGIN;
    x_max = BOTTOM_RIGHT(1) - MARGIN;
    y_max = TOP_LEFT(2) - MARGIN;
    y_min = BOTTOM_RIGHT(2) + MARGIN;

    for i = 1:size(top_rects,1)
        L = top_rects(i,1);
        B = top_rects(i,2);
        W = top_rects(i,3);
        ID = top_rects(i,5);

        options = [B, L, 0; L, B, 1];
        placed = false;

        for j = 1:2
            w = options(j,1);
            h = options(j,2);
            rot = options(j,3);

            for k = 1:size(base_map,1)
                x_pos = base_map(k,1);
                y_pos = base_map(k,3);

                if (x_pos + w > x_max) || (y_pos + h > y_max) || (x_pos < x_min) || (y_pos < y_min)
                    continue;
                end

                conflict = false;
                for t = 1:size(top_placements,1)
                    px = top_placements(t,1);
                    py = top_placements(t,2);
                    pw = top_placements(t,4);
                    ph = top_placements(t,5);
                    if ~(x_pos + w <= px || x_pos >= px + pw || ...
                         y_pos + h <= py || y_pos >= py + ph)
                        conflict = true;
                        break;
                    end
                end
                if conflict, continue; end

                support_area = 0;
                for m = 1:size(base_map,1)
                    bx1 = base_map(m,1); bx2 = base_map(m,2);
                    by1 = base_map(m,3); by2 = base_map(m,4);
                    ix1 = max(x_pos, bx1);
                    ix2 = min(x_pos + w, bx2);
                    iy1 = max(y_pos, by1);
                    iy2 = min(y_pos + h, by2);
                    if ix2 > ix1 && iy2 > iy1
                        support_area = support_area + (ix2 - ix1) * (iy2 - iy1);
                    end
                end

                if support_area >= 0.65 * w * h
                    top_placements(idx,:) = [x_pos, y_pos, H, w, h, W, 2, ID, rot];
                    idx = idx + 1;
                    placed = true;
                    break;
                end
            end
            if placed, break; end
        end

        if ~placed
            fprintf('Top layer: Could not place box %.2f x %.2f\n', L, B);
            rejected_ids = [rejected_ids; ID];
        end
    end
end


