%{
function [fixedDimInterpPlan,numComputedSamples] = exampleHelperManipulatorRRT(graspState, startConfig,goalConfig,ID, boxPosition, boxDim,maxNumOfBoxes)
%EXAMPLEHELPERMANIPULATORRRT This helper sets up the collision environment 
% and uses manipulatorRRT for collision-free planning
%
%
coder.extrinsic("exampleHelperGetInitActorProp")
persistent baseLoc baseDim benchLoc benchDim palletDim palletLoc 
if isempty(palletDim)
    baseLoc = zeros(1,3);
    baseDim = zeros(1,3);
    benchLoc = zeros(1,3);
    benchDim = zeros(1,3);
    palletLoc = zeros(1,3);
    palletDim = zeros(1,3);
    [baseLoc,baseDim,benchLoc,benchDim,palletLoc,palletDim] = exampleHelperGetInitActorProp();
end

NUMDOF = 6; 
NUMPATHSAMPLES = 200;

robot = exampleHelperSetUpCobot();

% Attach the Box to the end-effector if the grasp is active
if graspState == true
    boxCenter = rigidBody('boxCenter','MaxNumCollisions',1);
    boxCenterJnt = rigidBodyJoint('boxCenterJoint','fixed');
    setFixedTransform(boxCenterJnt,trvec2tform([0 0 0])); % Overlap with current end-effector
    boxCenter.Joint = boxCenterJnt;
    cBox = collisionBox(1.1*boxDim,boxDim,1.1*boxDim);
    cBox.Pose = trvec2tform([0 -boxDim/2-0.1 0]);

    addCollision(boxCenter,cBox);
    addBody(robot,boxCenter,'4cup_assembly')
end

% Extract the updated collision environment for the planner
collisionEnv = exampleHelperGetCollisionEnvironment(ID,graspState,boxDim,boxPosition,maxNumOfBoxes,baseLoc,baseDim,benchDim,benchLoc,palletDim,palletLoc);

%{
% After placing the box, add it as a collision object (if released)
if ~graspState
    % Add collision box at placed location
    pos = boxPosition;       % Bottom center of the box
    dims = boxDim;                  % Box dimensions

    placedBox = collisionBox(dims(1), dims(2), dims(3));
    placedBox.Pose = trvec2tform(pos + [0, 0, dims(3)/2]);  % Center in Z

    % Add to collision environment (which will be used in next planner creation)
    collisionEnv{end+1} = placedBox;
end
%}

% Setup the planner
planner = manipulatorRRT(robot,collisionEnv);

planner.IgnoreSelfCollision = true;
planner.SkippedSelfCollisions = "Parent";
planner.MaxConnectionDistance = 0.3;
planner.ValidationDistance = 0.05;

% For repeatable results, seed the random number generator and store
% the current seed value.
prevseed = rng(0);

% Plan and interpolate.

[planOut, ~] = planner.plan(startConfig(:)',goalConfig(:)');
shortenedPlan = planner.shorten(planOut, 5);
numOfInterp = floor((NUMPATHSAMPLES - size(shortenedPlan,1))/(size(shortenedPlan,1)-1));
interpolatedPlan = planner.interpolate(shortenedPlan,numOfInterp);
numComputedSamples = size(interpolatedPlan,1);

% Move the samples into one of fixed dimension
fixedDimInterpPlan = zeros(NUMDOF, NUMPATHSAMPLES);
fixedDimInterpPlan(:,1:numComputedSamples) = interpolatedPlan(1:numComputedSamples,:)';

% Pad the end of the output matrix with the goal state if the
% interpolated plan doesn't have enough samples
if numComputedSamples < NUMPATHSAMPLES
    fixedDimInterpPlan(:,(numComputedSamples+1):NUMPATHSAMPLES) = repmat(goalConfig(:), 1, NUMPATHSAMPLES-numComputedSamples);
else
    fixedDimInterpPlan = fixedDimInterpPlan(:,1:NUMPATHSAMPLES);
end

% Restore the random number generator to the previously stored seed.
rng(prevseed);

end

%}



%{

function [fixedDimInterpPlan, numComputedSamples] = helperPathPanning(graspState, startConfig, preGoalConfig, goalConfig, ID, boxPosition, boxDim, maxNumOfBoxes, layer)
% Path planner that inserts a fixed intermediate waypoint (preGoalConfig)

NUMDOF = 6;
NUMPATHSAMPLES = 200;
fixedDimInterpPlan = zeros(NUMDOF, NUMPATHSAMPLES);
numComputedSamples = 0;

% Set up robot and environment
robot = exampleHelperSetUpCobot();

coder.extrinsic("exampleHelperGetInitActorProp");
persistent baseLoc baseDim benchLoc benchDim palletDim palletLoc
if isempty(palletDim)
    baseLoc = zeros(1,3);
    baseDim = zeros(1,3);
    benchLoc = zeros(1,3);
    benchDim = zeros(1,3);
    palletLoc = zeros(1,3);
    palletDim = zeros(1,3);
    [baseLoc,baseDim,benchLoc,benchDim,palletLoc,palletDim] = exampleHelperGetInitActorProp();
end

% Add box to robot if grasp is active
if graspState
    boxCenter = rigidBody('boxCenter','MaxNumCollisions',1);
    boxCenterJnt = rigidBodyJoint('boxCenterJoint','fixed');
    setFixedTransform(boxCenterJnt, trvec2tform([0 0 0]));
    boxCenter.Joint = boxCenterJnt;

    cBox = collisionBox(1.1 * boxDim, boxDim, 1.1 * boxDim);
    cBox.Pose = trvec2tform([0 -boxDim/2 - 0.1 0]);

    addCollision(boxCenter, cBox);
    addBody(robot, boxCenter, '4cup_assembly');
end

% Set up collision environment
collisionEnv = exampleHelperGetCollisionEnvironment(ID, graspState, boxDim, boxPosition, maxNumOfBoxes, baseLoc, baseDim, benchDim, benchLoc, palletDim, palletLoc);

% Set up RRT planner
planner = manipulatorRRT(robot, collisionEnv);
planner.IgnoreSelfCollision = true;
planner.SkippedSelfCollisions = "Parent";
planner.MaxConnectionDistance = 0.3;
planner.ValidationDistance = 0.05;

% Determine whether to use the intermediate preGoalConfig
usePreGoal = (graspState && (layer == 1 || layer == 2));

if usePreGoal
    % Plan: start → pre-goal
    [path1, ~] = planner.plan(startConfig(:)', preGoalConfig(:)');
    shortPath1 = planner.shorten(path1, 5);

    % Plan: pre-goal → goal
    [path2, ~] = planner.plan(preGoalConfig(:)', goalConfig(:)');
    shortPath2 = planner.shorten(path2, 5);

    % Combine both plans (remove duplicate preGoal)
    fullPlan = [shortPath1; shortPath2(2:end,:)];
else
    % Direct plan: start → goal
    [path, ~] = planner.plan(startConfig(:)', goalConfig(:)');
    fullPlan = planner.shorten(path, 5);
end


numOfInterp = floor((NUMPATHSAMPLES - size(fullPlan,1)) / (size(fullPlan,1)-1));
interpolatedPlan = planner.interpolate(fullPlan, numOfInterp);
%numComputedSamples = size(interpolatedPlan,1);

% Filter interpolated waypoints based on end-effector Z ≥ 0.22
validConfigs = [];
for i = 1:size(interpolatedPlan, 1)
    q = interpolatedPlan(i, :);
    T = getTransform(robot, q, robot.BodyNames{end});  % or use your actual EE name
    if T(3,4) >= 0.22
        validConfigs = [validConfigs; q];
    end
end

numComputedSamples = size(validConfigs, 1);

% Truncate if too long
if numComputedSamples > NUMPATHSAMPLES
    validConfigs = validConfigs(1:NUMPATHSAMPLES, :);
    numComputedSamples = NUMPATHSAMPLES;
end

%Fill ouput matrix
fixedDimInterpPlan(:,1:numComputedSamples) = validConfigs(1:numComputedSamples,:)' ;

if numComputedSamples < NUMPATHSAMPLES
    fixedDimInterpPlan(:, (numComputedSamples+1):NUMPATHSAMPLES) = ...
        repmat(goalConfig(:), 1, NUMPATHSAMPLES - numComputedSamples);
else
    fixedDimInterpPlan = fixedDimInterpPlan(:,1:NUMPATHSAMPLES);
end
%}

function [fixedDimInterpPlan,numComputedSamples] = exampleHelperManipulatorRRT(graspState, startConfig,goalConfig,ID, boxPosition, boxDim,maxNumOfBoxes,  curr_box_dim,Dynamic_box_pos, Dynamic_box_dim)
%EXAMPLEHELPERMANIPULATORRRT This helper sets up the collision environment 
% and uses manipulatorRRT for collision-free planning
%
%
coder.extrinsic("exampleHelperGetInitActorProp")
persistent baseLoc baseDim benchLoc benchDim palletDim palletLoc %temp_Dim temp_boxLoc Rej_Dim Rej_boxLoc
if isempty(palletDim)
    baseLoc = zeros(1,3);
    baseDim = zeros(1,3);
    benchLoc = zeros(1,3);
    benchDim = zeros(1,3);
    palletLoc = zeros(1,3);
    palletDim = zeros(1,3);
    %temp_boxLoc = zeros(1,3);
    %temp_Dim = zeros(1,3);
    %Rej_boxLoc = zeros(1,3);
    %Rej_Dim = zeros(1,3);
    [baseLoc,baseDim,benchLoc,benchDim,palletLoc,palletDim] = exampleHelperGetInitActorProp();
    %[baseLoc,baseDim,benchLoc,benchDim,palletLoc,palletDim,temp_boxLoc,temp_Dim,Rej_boxLoc,Rej_Dim] = exampleHelperGetInitActorProp();
end

NUMDOF = 6; 
NUMPATHSAMPLES = 200;

robot = exampleHelperSetUpCobot();

% Attach the Box to the end-effector if the grasp is active
if graspState == true
    boxCenter = rigidBody('boxCenter','MaxNumCollisions',1);
    boxCenterJnt = rigidBodyJoint('boxCenterJoint','fixed');
    setFixedTransform(boxCenterJnt,trvec2tform([0 0 0])); % Overlap with current end-effector
    boxCenter.Joint = boxCenterJnt;
    %cBox = collisionBox(1.1*boxDim,boxDim,1.1*boxDim);
    L = curr_box_dim(1);
    W = curr_box_dim(2);
    H = curr_box_dim(3);

    cBox = collisionBox(1.1*L, W, 1.1*H);   
    cBox.Pose = trvec2tform([0 -W/2-0.1 0]);

    addCollision(boxCenter,cBox);
    addBody(robot,boxCenter,'4cup_assembly')
end
 
% Extract the updated collision environment for the planner
collisionEnv = exampleHelperGetCollisionEnvironment(ID,graspState,boxDim,boxPosition,maxNumOfBoxes,baseLoc,baseDim,benchDim,benchLoc,palletDim,palletLoc,Dynamic_box_pos, Dynamic_box_dim);
%collisionEnv = exampleHelperGetCollisionEnvironment(ID,graspState,boxDim,boxPosition,maxNumOfBoxes,baseLoc,baseDim,benchDim,benchLoc,palletDim,palletLoc,temp_boxLoc,temp_Dim,Rej_boxLoc,Rej_Dim);


% Setup the planner
planner = manipulatorRRT(robot,collisionEnv);

planner.IgnoreSelfCollision = true;
planner.SkippedSelfCollisions = "Parent";
planner.MaxConnectionDistance = 0.3;
planner.ValidationDistance = 0.05;

% For repeatable results, seed the random number generator and store
% the current seed value.
prevseed = rng(0);

% Plan and interpolate.

[planOut, ~] = planner.plan(startConfig(:)',goalConfig(:)');
shortenedPlan = planner.shorten(planOut, 5);
numOfInterp = floor((NUMPATHSAMPLES - size(shortenedPlan,1))/(size(shortenedPlan,1)-1));
interpolatedPlan = planner.interpolate(shortenedPlan,numOfInterp);
numComputedSamples = size(interpolatedPlan,1);

% Move the samples into one of fixed dimension
fixedDimInterpPlan = zeros(NUMDOF, NUMPATHSAMPLES);
fixedDimInterpPlan(:,1:numComputedSamples) = interpolatedPlan(1:numComputedSamples,:)';

% Pad the end of the output matrix with the goal state if the
% interpolated plan doesn't have enough samples
if numComputedSamples < NUMPATHSAMPLES
    fixedDimInterpPlan(:,(numComputedSamples+1):NUMPATHSAMPLES) = repmat(goalConfig(:), 1, NUMPATHSAMPLES-numComputedSamples);
else
    fixedDimInterpPlan = fixedDimInterpPlan(:,1:NUMPATHSAMPLES);
end

% Restore the random number generator to the previously stored seed.
rng(prevseed);

end

