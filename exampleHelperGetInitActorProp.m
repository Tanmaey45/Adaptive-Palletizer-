function [baseLoc,baseDim,benchLoc,benchDim,palletLoc,palletDim] = exampleHelperGetInitActorProp()
%function [baseLoc,baseDim,benchLoc,benchDim,palletLoc,palletDim,temp_boxLoc,temp_Dim,Rej_boxLoc, Rej_Dim] = exampleHelperGetInitActorProp()
%HELPERGETINITACTORPROP Queries the sim3d world for workspace actor properties

%Copyright 2024 The MathWorks, Inc.
Wr = sim3d.World.getWorld(bdroot);
actorList = Wr.Actors;

% Extract the collision environment for spawnbench
actor1 = actorList.('collBench');
maxVertices = max(double(actor1.Vertices));
minVertices = min(double(actor1.Vertices));

boxCenterLoc = (maxVertices + minVertices)/2;
benchDim = maxVertices - minVertices;
objLoc1 = double(actor1.Translation) + boxCenterLoc;

% Convert to SL frame - Spawn Bench
benchLoc = [objLoc1(1) -objLoc1(2) objLoc1(3)];

% Extract the collision environment for base below BOT
actor2 = actorList.('collBase');
maxVertices = max(double(actor2.Vertices));
minVertices = min(double(actor2.Vertices));
baseDim = maxVertices - minVertices;
objLoc2 = double(actor2.Translation);


% Convert to SL frame - Base of BOT
baseLoc = [objLoc2(1) -objLoc2(2) objLoc2(3)];

%{

******* For reference *****

%Box spawn bench
Bench = sim3d.Actor('ActorName','collBench');
Bench.createShape('box',[0.8 0.8 0.5]);
Bench.Translation = [-0.5 -0.7 0.25];
Bench.Color = [87, 67, 60]/256;
add(World,Bench,Actor);

%Rejection conveyer
Bench_R = sim3d.Actor('ActorName','collBench_R');
Bench_R.createShape('box',[0.4 0.8 0.3]);
Bench_R.Translation = [-1.2 -0.7 0.25];
Bench_R.Color = [180, 40, 36]/256;
add(World,Bench_R,Actor);


%Layer 2 storage bench
Bench_2 = sim3d.Actor('ActorName','collBench_2');
Bench_2.createShape('box',[1.2 0.8 0.5]);
Bench_2.Translation = [0.4 0.8 0.25];
Bench_2.Color = [40, 170, 46]/256;
add(World,Bench_2,Actor);

%}

% Extract the collision environment for Pallet
actor3 = actorList.('collPallet');
maxVertices = max(double(actor3.Vertices));
minVertices = min(double(actor3.Vertices));

boxCenterLoc = (maxVertices + minVertices)/2;
palletDim = maxVertices - minVertices;
objLoc3 = double(actor3.Translation) + boxCenterLoc;
    
% Convert to SL frame - Pallet
palletLoc = [objLoc3(1) -objLoc3(2) objLoc3(3)];



%%.............New Actors...........%%

%{    
% Extract the collision environment for Rejection bench
actor4 = actorList.('collBench_R');
maxVertices = max(double(actor4.Vertices));
minVertices = min(double(actor4.Vertices));

boxCenterLoc = (maxVertices + minVertices)/2;
Rej_Dim = maxVertices - minVertices;
objLoc4 = double(actor4.Translation) + boxCenterLoc;

% Convert to SL frame - Rejection box
Rej_boxLoc = [objLoc4(1) -objLoc4(2) objLoc4(3)];


% Extract the collision environment for temporary box
actor5 = actorList.('collBench_2');
maxVertices = max(double(actor5.Vertices));
minVertices = min(double(actor5.Vertices));

boxCenterLoc = (maxVertices + minVertices)/2;
temp_Dim = maxVertices - minVertices;
objLoc5 = double(actor5.Translation) + boxCenterLoc;

% Convert to SL frame - temp box
temp_boxLoc = [objLoc5(1) -objLoc5(2) objLoc5(3)];
%}

end

