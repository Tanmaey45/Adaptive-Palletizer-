function rbt = exampleHelperSetUpCobot()
%EXAMPLEHELPERSETUPCOBOT helper function to build the robot rigid body tree

%   Copyright 2024 The MathWorks, Inc.

% Setup the rigidBodyTree
rbt = rigidBodyTree(MaxNumBodies=14,DataFormat="row");
rbt.BaseName = 'world';

% Define the base of the robot as a raised platform 
extBase = rigidBody('externalBase','MaxNumCollisions',1);
extBaseJnt = rigidBodyJoint('externalBaseJoint','fixed');
setFixedTransform(extBaseJnt,trvec2tform([0 0 0.51]));
extBase.Joint = extBaseJnt;

% Add base to the tree
addBody(rbt,extBase,'world')

% Load the robot rigidBodyTree
urrobot = loadrobot("universalUR10e",DataFormat="row");

% Add the robot tree to the base 
addSubtree(rbt,'externalBase',urrobot)

% Load the gripper rigidBodyTree
gripper = loadrobot("robotiqEPick4CupVacuumAssembly", Dataformat="row");

% Add the gripper to the tree
addSubtree(rbt,'tool0',gripper)
end

