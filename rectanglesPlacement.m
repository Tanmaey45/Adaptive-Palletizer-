function placeRectanglesFromExcel()
    % Read Excel file
    filename = 'Rectangles.xlsx';
    data = readtable(filename);

    % Assume rectangles are in 2nd and 3rd columns (like df.iloc[:, 1], df.iloc[:, 2])
    rectangles = [data{:,2}, data{:,3}];

    % Prepend rectangle (0.2, 0.2)
    rectangles = [[0.2, 0.2]; rectangles];

    % Proceed with placement
    placeRectangles(rectangles);
end

function placeRectangles(rectangles)
    TOP_LEFT = [0, -0.1];
    BOTTOM_RIGHT = [1.1, -0.76];
    MARGIN = 0.02;
    SPACING = 0.02;

    usable_width = abs(TOP_LEFT(1) - BOTTOM_RIGHT(1)) - 2 * MARGIN;
    usable_height = abs(TOP_LEFT(2) - BOTTOM_RIGHT(2)) - 2 * MARGIN;

    shelf_y = TOP_LEFT(2) - MARGIN;
    shelf_height = 0;
    x_cursor = TOP_LEFT(1) + MARGIN;

    placements = [];
    idx = 1;

    for i = 1:size(rectangles, 1)
        L = rectangles(i,1);
        B = rectangles(i,2);

        options = [B, L, 0; L, B, 1]; % [width, height, rotated]
        options = sortrows(options, 2); % prioritize lower height

        placed = false;
        for j = 1:2
            w = options(j,1);
            h = options(j,2);
            rotated = options(j,3);

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

            placements(idx,:) = [x_cursor, shelf_y - h, w, h, rotated];
            x_cursor = x_cursor + w + SPACING;
            shelf_height = max(shelf_height, h);
            placed = true;
            idx = idx + 1;
            break;
        end

        if ~placed
            fprintf('Rectangle too big to fit: %f x %f\n', L, B);
        end
    end

    % Plot the layout
    figure;
    hold on;
    xlim([TOP_LEFT(1) - 0.05, BOTTOM_RIGHT(1) + 0.05]);
    ylim([BOTTOM_RIGHT(2) - 0.05, TOP_LEFT(2) + 0.05]);
    axis equal;
    title('2D Bin Packing with Rotation (Length-Breadth Logic)');
    xlabel('X');
    ylabel('Y');
    grid on;

    for i = 1:size(placements, 1)
        x = placements(i,1);
        y = placements(i,2);
        w = placements(i,3);
        h = placements(i,4);
        rot = placements(i,5);

        rectangle('Position', [x, y, w, h], ...
                  'EdgeColor', 'b', 'FaceColor', [0, 1, 1, 0.6], 'LineWidth', 1);
        text(x + w/2, y + h/2, sprintf('%d%s', i, ternary(rot, 'R', '')), ...
             'HorizontalAlignment', 'center', 'FontSize', 8);
    end
    hold off;

    % Save to Excel
    output.ID = (1:size(placements,1))';
    output.X = placements(:,2);
    output.Y = -1 * placements(:,1);
    output.Length = placements(:,3);
    output.Breadth = placements(:,4);
    output.Rotated = placements(:,5);

    writetable(struct2table(output), 'rectangle_placements_ROTASISS.xlsx');
    disp('Placements saved to rectangle_placements_ROTASISS.xlsx');
    disp(output);
end

function out = ternary(cond, trueVal, falseVal)
    if cond
        out = trueVal;
    else
        out = falseVal;
    end
end
