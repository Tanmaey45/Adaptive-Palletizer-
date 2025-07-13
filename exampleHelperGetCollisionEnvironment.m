function collisionArraySubset = exampleHelperGetCollisionEnvironment(ID,graspState,boxDim,boxPosition,maxNumOfBoxes,baseLoc,baseDim,benchDim,benchLoc,palletDim,palletLoc, Dynamic_box_pos, Dynamic_box_dim)
%exampleHelperGetCollisionEnvironment Set up the collision environment for the planner

%   Copyright 2024 The MathWorks, Inc.

persistent collisionArray
coder.varsize('collisionArray',[1,50]);

% Initialize the collision environment with the existing actors
if isempty(collisionArray)
    
    collisionArray = cell(1,0);
    
    % Initialize a cell array of collisionBoxes placed away from the robot
    for i=coder.unroll(1:50)
        if i<=maxNumOfBoxes+3
        collisionArray{end+1} = collisionBox(boxDim,boxDim,boxDim,Pose=trvec2tform([3,3,0]));
        end
    end

    % Update the first three collision boxes with information from the
    % existing collision environment
    
    % Update the collisionBox for the bench
    collisionArray{1}.X = baseDim(1);
    collisionArray{1}.Y = baseDim(2);
    collisionArray{1}.Z = baseDim(3);
    collisionArray{1}.Pose = trvec2tform(baseLoc);

    collisionArray{2}.X = benchDim(1);
    collisionArray{2}.Y = benchDim(2);
    collisionArray{2}.Z = benchDim(3);
    collisionArray{2}.Pose = trvec2tform(benchLoc);

    % Update the collisionBox for the pallet
    collisionArray{3}.X = palletDim(1);
    collisionArray{3}.Y = palletDim(2);
    collisionArray{3}.Z = palletDim(3);
    collisionArray{3}.Pose = trvec2tform(palletLoc);
    
    % Update the collisionBox for box0
    collisionArray{4}.X = boxDim;
    collisionArray{4}.Y = boxDim;
    collisionArray{4}.Z = boxDim;
    collisionArray{4}.Pose = trvec2tform(boxPosition);

    %{

    %Update the collisionBox for temporary block
    collisionArray{5}.X = temp_Dim(1);
    collisionArray{5}.Y = temp_Dim(2);
    collisionArray{5}.Z = temp_Dim(3);
    collisionArray{5}.Pose = trvec2tform(temp_boxLoc);

    %Update the collisionBox for Rejection block
    collisionArray{6}.X = Rej_Dim(1);
    collisionArray{6}.Y = Rej_Dim(2);
    collisionArray{6}.Z = Rej_Dim(3);
    collisionArray{6}.Pose = trvec2tform(Rej_boxLoc);

    %}
end

% After the box has been dropped off update the position of the dropped
% box and the spawned box

%{
% As boxes are spawned, update the properties of the next collisionBox
if graspState == false
    % New box is spawned when the old box is dropped off i.e. when the graspState is false
    if ID < maxNumOfBoxes
        collisionArray{ID+4}.Pose = trvec2tform(boxPosition);
    end
    % Simultaneously update the position of the dropped box 
    % (There is no dropped box at the first time step)
    if ID>=1 
        droppedBoxPoseUpdate = exampleHelperPalletArrangement(ID-1,palletDim,palletLoc,boxDim);
        collisionArray{ID+3}.Pose = trvec2tform(droppedBoxPoseUpdate);
    end
end

%}

% As boxes are spawned, update the properties of the next collisionBox
if graspState == false && Dynamic_box_pos(1) ~= -1
    % New box is spawned when the old box is dropped off i.e. when the graspState is false
    if ID < maxNumOfBoxes
        collisionArray{ID+4}.Pose = trvec2tform(boxPosition);
    end
    % Simultaneously update the position of the dropped box 
    % (There is no dropped box at the first time step)
    if ID>=1 
        %We need to feed the position of the box
        %droppedBoxPoseUpdate = exampleHelperPalletArrangement(ID-1,palletDim,palletLoc,boxDim);
        L = Dynamic_box_pos(1);
        W = Dynamic_box_pos(2);
        H = Dynamic_box_pos(3);
        droppedBoxPoseUpdate = [L,W,H];
        collisionArray{ID+3}.X = Dynamic_box_dim(1);
        collisionArray{ID+3}.Y = Dynamic_box_dim(2);
        collisionArray{ID+3}.Z = Dynamic_box_dim(3);
        collisionArray{ID+3}.Pose = trvec2tform(droppedBoxPoseUpdate);
        fprintf('Collision box %d added', ID);
    end
end


% If the robot is holding the current box, the box is attached to the robot
% tree and temporarily removed from the environment
if graspState == true
    if ID < maxNumOfBoxes
        collisionArray{ID+4}.Pose = trvec2tform([3,3,0]);
    end
end

% Trim the unused boxes
collisionArraySubset = cell(1,0);
for i = coder.unroll(1:50)
    if i <= ID+4
        collisionArraySubset{end+1} = collisionArray{i};
    end
end

end