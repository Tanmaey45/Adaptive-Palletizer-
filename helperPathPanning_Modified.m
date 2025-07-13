function [fixedDimInterpPlan, numComputedSamples] = helperPathPanning(graspState, startConfig, preGoalConfig, goalConfig, ID, boxPosition, boxDim, maxNumOfBoxes)
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

% After placing the box, add it as a collision object (if released)
if ~graspState
    % Add collision box at placed location
    pos = boxPosition(ID, :);       % Bottom center of the box
    dims = boxDim;                  % Box dimensions

    placedBox = collisionBox(dims(1), dims(2), dims(3));
    placedBox.Pose = trvec2tform(pos + [0, 0, dims(3)/2]);  % Center in Z

    % Add to collision environment (which will be used in next planner creation)
    collisionEnv{end+1} = placedBox;
end


% Set up collision environment
collisionEnv = exampleHelperGetCollisionEnvironment(ID, graspState, boxDim, boxPosition, maxNumOfBoxes, baseLoc, baseDim, benchDim, benchLoc, palletDim, palletLoc);

% Set up RRT planner
planner = manipulatorRRT(robot, collisionEnv);
planner.IgnoreSelfCollision = true;
planner.SkippedSelfCollisions = "Parent";
planner.MaxConnectionDistance = 0.3;
planner.ValidationDistance = 0.05;

% Plan: start → pre-goal
[path1, ~] = planner.plan(startConfig(:)', preGoalConfig(:)');
shortPath1 = planner.shorten(path1, 5);

% Plan: pre-goal → goal
[path2, ~] = planner.plan(preGoalConfig(:)', goalConfig(:)');
shortPath2 = planner.shorten(path2, 5);

% Combine and interpolate
fullPlan = [shortPath1; shortPath2(2:end,:)]; % remove duplicate config
numOfInterp = floor((NUMPATHSAMPLES - size(fullPlan,1)) / (size(fullPlan,1)-1));

interpolatedPlan = planner.interpolate(fullPlan, numOfInterp);


% Step 2: Check collision for the final plan
isCollisionFree = true;
for i = 1:size(interpolatedPlan,1)
    q = interpolatedPlan(i,:);
    inCollision = checkCollision(robot, q, planner.Environment, 'IgnoreSelfCollision', false);
    if inCollision
        isCollisionFree = false;
        break;
    end
end

fallbackGoalConfig = [2.522,-0.8261,0.9149,4.624,-1.571,4.092];

% Step 3: If collision detected, update goalConfig and replan
if ~isCollisionFree
    disp("Collision detected in final path. Switching to fallback goal.");
    goalConfig = fallbackGoalConfig;  % Define this earlier
   
    % Rebuild full plan
    fullPlan = planner.plan(startConfig(:)', goalConfig(:)');
    interpolatedPlan = interpolate(planner, fullPlan, 10);
end


numComputedSamples = size(interpolatedPlan,1);

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

% Fill output matrix
%{
fixedDimInterpPlan(:,1:numComputedSamples) = interpolatedPlan(1:numComputedSamples,:)';

if numComputedSamples < NUMPATHSAMPLES
    fixedDimInterpPlan(:,(numComputedSamples+1):NUMPATHSAMPLES) = repmat(goalConfig(:), 1, NUMPATHSAMPLES - numComputedSamples);
else
    fixedDimInterpPlan = fixedDimInterpPlan(:,1:NUMPATHSAMPLES);
end

end
%}