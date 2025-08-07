function despawnBox(id)
% DESPAWNBOX removes the Sim3D actor with name 'collBox<ID>' if it exists

    % Get reference to the Sim3D world
    World = sim3d.World.getWorld(bdroot);

    % Construct the actor name
    %boxName = ['collBox' num2str(id)];
    boxName = ['collBox'];

    % Try to find the actor
    boxActor = World.Root.findBy('ActorName', boxName, 'first');

    % If found, delete it
    if ~isempty(boxActor)
        delete(boxActor);
        disp(['Deleted actor: ' boxName]);
    else
        disp(['Actor not found: ' boxName]);
    end

end
