function spawnBox(id,boxPosition,boxDim)
% SPAWNBOX creates a box actor in the world

%   Copyright 2024 The MathWorks, Inc.

bosPosSim3D = [boxPosition(1), -boxPosition(2), boxPosition(3)]; % Convert position from SL world to Sim3D world
World = sim3d.World.getWorld(bdroot);
% Spawn new actor only if it doesn't already exists
if isempty(World.Root.findBy('ActorName',['collBox' num2str(id)],'first'))
    Box = sim3d.Actor('ActorName',['collBox' num2str(id)],'Mobility',sim3d.utils.MobilityTypes.Movable);
    add(World,Box)
    createShape(Box,'box', [boxDim(1),boxDim(2),boxDim(3)]);
    Box.Translation = bosPosSim3D;
    Box.Color = [200 100 16]/256;
    %Box.Physics = true;
    Box.Collisions = true;
    Box.Parent = World.Root.findBy('ActorName','Warehouse','first');
end

end

