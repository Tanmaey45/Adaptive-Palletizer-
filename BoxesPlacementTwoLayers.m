function place3DBoxesFromExcel()
    % Read Excel file
    filename = 'Boxes.xlsx';
    data = readtable(filename);

    % Assume columns: Length, Breadth, Weight
    rectangles = [data{:,2}, data{:,3}, data{:,4}];

    % Add initial 0.2 x 0.2 rectangle with arbitrary weight (e.g. 5)
    rectangles = [[0.2, 0.2, 5]; rectangles];

    % Add ID and Planar Density column
    IDs = (1:size(rectangles,1))';
    planar_density = rectangles(:,3) ./ (rectangles(:,1) .* rectangles(:,2));
    rectangles = [rectangles, planar_density, IDs];

    % Sort by descending planar density
    rectangles = sortrows(rectangles, -4); % 4th column is planar density


    % Split into bottom and top layers
    %Choose optimum placement division of rectangles between top and bottom
    %layer
    N = size(rectangles,1);  
    N_bottom = round(0.6 * N);
    bottom_rects = rectangles(1:N_bottom, :);
    top_rects = rectangles(N_bottom+1:end, :);

    % Place bottom layer
    [bottom_placements, base_map] = placeLayer(bottom_rects, 0);

    % Place top layer, only if fully supported
    top_placements = placeTopLayer(top_rects, base_map);

    % Combine placements
    placements = [bottom_placements; top_placements];

    % Plot layout
    plot3DLayout(placements);

    % Save to Excel
    output.ID = (1:size(placements,1))';
    output.X = placements(:,1);
    output.Y = placements(:,2);
    output.Z = placements(:,6);
    output.Length = placements(:,3);
    output.Breadth = placements(:,4);
    output.Weight = placements(:,5);
    output.Layer = placements(:,7);

    writetable(struct2table(output), 'box_placements_3D.xlsx');
    disp('Placements saved to box_placements_3D.xlsx');
end

function [placements, base_map] = placeLayer(rectangles, z_layer)
    TOP_LEFT = [0, -0.1];
    BOTTOM_RIGHT = [1.1, -0.76];
    MARGIN = 0.01;
    SPACING = 0.02;
    H = 0.2;

    usable_width = abs(TOP_LEFT(1) - BOTTOM_RIGHT(1)) - 2 * MARGIN;
    usable_height = abs(TOP_LEFT(2) - BOTTOM_RIGHT(2)) - 2 * MARGIN;

    shelf_y = TOP_LEFT(2) - MARGIN;
    shelf_height = 0;
    x_cursor = TOP_LEFT(1) + MARGIN;

    placements = [];
    base_map = []; % for supporting layer 2
    idx = 1;
    c = 0;
    for i = 1:size(rectangles,1)
        L = rectangles(i,1);
        B = rectangles(i,2);
        W = rectangles(i,3);

        options = [B, L, 0; L, B, 1]; % [width, height, rotated]
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

            placements(idx,:) = [x_cursor, shelf_y - h, w, h, W, z_layer, 1]; % Z = 0 for bottom layer, Layer = 1
            base_map(idx,:) = [x_cursor, x_cursor + w, shelf_y - h, shelf_y, W]; % [x_start, x_end, y_start, y_end, weight]
            x_cursor = x_cursor + w + SPACING;
            shelf_height = max(shelf_height, h);
            placed = true;
            idx = idx + 1;
            break;
        end

        if ~placed
            fprintf('Bottom layer: Box too big to fit: %f x %f\n', L, B);
            c = c + 1;
        end
    end
    fprintf('count: %f\n',c);
end

function top_placements = placeTopLayer(top_rects, base_map)
    H = 0.22; % Fixed height
    top_placements = [];
    idx = 1;

    % Define pallet boundaries
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

        options = [B, L, 0; L, B, 1]; % width, depth, rotation flag
        placed = false;

        for j = 1:2
            w = options(j,1);
            h = options(j,2);
            rot = options(j,3);

            % Try positions from base_map
            for k = 1:size(base_map,1)
                x_pos = base_map(k,1);
                y_pos = base_map(k,3);

                % Check if box stays within pallet bounds
                if (x_pos + w > x_max) || (y_pos + h > y_max) || (x_pos < x_min) || (y_pos < y_min)
                    continue;
                end

                % Check collision with already placed top boxes
                conflict = false;
                for t = 1:size(top_placements,1)
                    placed_x = top_placements(t,1);
                    placed_y = top_placements(t,2);
                    placed_w = top_placements(t,3);
                    placed_h = top_placements(t,4);

                    if ~(x_pos + w <= placed_x || x_pos >= placed_x + placed_w || ...
                         y_pos + h <= placed_y || y_pos >= placed_y + placed_h)
                        conflict = true;
                        break;
                    end
                end
                if conflict, continue; end

                % Check support area from bottom layer
                support_area = 0;
                for m = 1:size(base_map,1)
                    bx1 = base_map(m,1); bx2 = base_map(m,2);
                    by1 = base_map(m,3); by2 = base_map(m,4);

                    % Overlap rectangle
                    ix1 = max(x_pos, bx1);
                    ix2 = min(x_pos + w, bx2);
                    iy1 = max(y_pos, by1);
                    iy2 = min(y_pos + h, by2);

                    if ix2 > ix1 && iy2 > iy1
                        support_area = support_area + (ix2 - ix1) * (iy2 - iy1);
                    end
                end

                box_area = w * h;
                if support_area >= 0.8 * box_area
                    top_placements(idx,:) = [x_pos, y_pos, w, h, W, H, 2];
                    idx = idx + 1;
                    placed = true;
                    break;
                end
            end
            if placed, break; end
        end

        if ~placed
            fprintf('Top layer: Could not place box %.2f x %.2f\n', L, B);
        end
    end
end



function plot3DLayout(placements)
    figure;
    hold on;
    axis equal;
    grid on;
    view(3);
    xlabel('X'); ylabel('Y'); zlabel('Z');
    title('3D Bin Packing (2 Layers)');

    for i = 1:size(placements,1)
        x = placements(i,1);
        y = placements(i,2);
        z = placements(i,6);
        w = placements(i,3);
        d = placements(i,4);
        h = 0.2;
        layer = placements(i,7);

        c = [0, 1, 1, 0.6];
        if layer == 2
            c = [1, 0.6, 0, 0.7]; % top layer: orange
        end

        fill3([x x+w x+w x], [y y y+d y+d], [z z z z], c);        % bottom face
        fill3([x x+w x+w x], [y y y y],     [z z z+h z+h], c);    % front face
        fill3([x x x x],     [y y y+d y+d], [z z z+h z+h], c);    % left face
        fill3([x+w x+w x+w x+w], [y y y+d y+d], [z z z+h z+h], c); % right face
        fill3([x x+w x+w x], [y+d y+d y+d y+d], [z z z+h z+h], c); % back face
        fill3([x x+w x+w x], [y y y+d y+d], [z+h z+h z+h z+h], c); % top face

        text(x + w/2, y + d/2, z + 0.1, sprintf('%d', i), ...
            'HorizontalAlignment','center','FontSize',7);
    end
    hold off;
end

